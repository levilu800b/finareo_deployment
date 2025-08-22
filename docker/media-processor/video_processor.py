#!/usr/bin/env python3
"""
Advanced Video Processing for LiveLens Platform
Handles video compression, thumbnail generation, and multi-quality encoding
"""

import os
import subprocess
import json
import tempfile
from pathlib import Path
from typing import Dict, List, Tuple
import boto3
from botocore.config import Config

class VideoProcessor:
    """Professional video processing for streaming platform"""
    
    def __init__(self):
        self.r2_endpoint = os.getenv('CLOUDFLARE_R2_ENDPOINT')
        self.r2_access_key = os.getenv('CLOUDFLARE_R2_ACCESS_KEY')
        self.r2_secret_key = os.getenv('CLOUDFLARE_R2_SECRET_KEY')
        self.r2_bucket = os.getenv('CLOUDFLARE_R2_BUCKET')
        
        # Initialize R2 client
        self.s3_client = boto3.client(
            's3',
            endpoint_url=self.r2_endpoint,
            aws_access_key_id=self.r2_access_key,
            aws_secret_access_key=self.r2_secret_key,
            config=Config(
                region_name='auto',
                s3={'addressing_style': 'path'}
            )
        )
        
        # Video quality profiles for different resolutions
        self.quality_profiles = {
            '360p': {
                'resolution': '640x360',
                'bitrate': '800k',
                'audio_bitrate': '128k',
                'preset': 'fast'
            },
            '480p': {
                'resolution': '854x480',
                'bitrate': '1200k',
                'audio_bitrate': '128k',
                'preset': 'fast'
            },
            '720p': {
                'resolution': '1280x720',
                'bitrate': '2500k',
                'audio_bitrate': '192k',
                'preset': 'medium'
            },
            '1080p': {
                'resolution': '1920x1080',
                'bitrate': '4500k',
                'audio_bitrate': '256k',
                'preset': 'medium'
            }
        }
    
    def get_video_info(self, video_path: str) -> Dict:
        """Extract video metadata using FFprobe"""
        try:
            cmd = [
                'ffprobe',
                '-v', 'quiet',
                '-print_format', 'json',
                '-show_format',
                '-show_streams',
                video_path
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            info = json.loads(result.stdout)
            
            # Extract relevant information
            video_stream = next((s for s in info['streams'] if s['codec_type'] == 'video'), None)
            audio_stream = next((s for s in info['streams'] if s['codec_type'] == 'audio'), None)
            
            return {
                'duration': float(info['format']['duration']),
                'size': int(info['format']['size']),
                'width': int(video_stream['width']) if video_stream else 0,
                'height': int(video_stream['height']) if video_stream else 0,
                'codec': video_stream['codec_name'] if video_stream else None,
                'audio_codec': audio_stream['codec_name'] if audio_stream else None,
                'bitrate': int(info['format']['bit_rate']) if 'bit_rate' in info['format'] else 0
            }
        except subprocess.CalledProcessError as e:
            raise Exception(f"Failed to get video info: {e}")
    
    def generate_thumbnail(self, video_path: str, output_path: str, timestamp: str = "00:00:10") -> bool:
        """Generate video thumbnail"""
        try:
            cmd = [
                'ffmpeg',
                '-i', video_path,
                '-ss', timestamp,
                '-vframes', '1',
                '-q:v', '2',
                '-y',
                output_path
            ]
            
            subprocess.run(cmd, check=True, capture_output=True)
            return True
        except subprocess.CalledProcessError:
            return False
    
    def compress_video(self, input_path: str, output_path: str, quality: str = '720p') -> bool:
        """Compress video for web streaming"""
        profile = self.quality_profiles.get(quality, self.quality_profiles['720p'])
        
        try:
            cmd = [
                'ffmpeg',
                '-i', input_path,
                '-c:v', 'libx264',
                '-preset', profile['preset'],
                '-crf', '23',
                '-vf', f"scale={profile['resolution']}:flags=lanczos",
                '-b:v', profile['bitrate'],
                '-maxrate', profile['bitrate'],
                '-bufsize', f"{int(profile['bitrate'][:-1]) * 2}k",
                '-c:a', 'aac',
                '-b:a', profile['audio_bitrate'],
                '-movflags', '+faststart',
                '-f', 'mp4',
                '-y',
                output_path
            ]
            
            subprocess.run(cmd, check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Video compression failed: {e}")
            return False
    
    def create_streaming_variants(self, input_path: str, output_dir: str) -> Dict[str, str]:
        """Create multiple quality variants for adaptive streaming"""
        variants = {}
        
        for quality, profile in self.quality_profiles.items():
            output_file = os.path.join(output_dir, f"video_{quality}.mp4")
            
            if self.compress_video(input_path, output_file, quality):
                variants[quality] = output_file
                print(f"Created {quality} variant: {output_file}")
            else:
                print(f"Failed to create {quality} variant")
        
        return variants
    
    def upload_to_r2(self, local_path: str, r2_key: str, content_type: str = 'video/mp4') -> str:
        """Upload file to Cloudflare R2"""
        try:
            with open(local_path, 'rb') as file:
                self.s3_client.upload_fileobj(
                    file,
                    self.r2_bucket,
                    r2_key,
                    ExtraArgs={
                        'ContentType': content_type,
                        'CacheControl': 'public, max-age=31536000'  # 1 year cache
                    }
                )
            
            # Return public URL
            return f"https://{self.r2_bucket}.r2.dev/{r2_key}"
        except Exception as e:
            print(f"Upload to R2 failed: {e}")
            return None
    
    def process_video_complete(self, video_path: str, video_id: str) -> Dict:
        """Complete video processing pipeline"""
        result = {
            'video_id': video_id,
            'status': 'processing',
            'variants': {},
            'thumbnail': None,
            'metadata': {}
        }
        
        try:
            # Get video metadata
            result['metadata'] = self.get_video_info(video_path)
            
            # Create temporary directory for processing
            with tempfile.TemporaryDirectory() as temp_dir:
                # Generate thumbnail
                thumbnail_path = os.path.join(temp_dir, f"{video_id}_thumbnail.jpg")
                if self.generate_thumbnail(video_path, thumbnail_path):
                    # Upload thumbnail to R2
                    thumbnail_url = self.upload_to_r2(
                        thumbnail_path, 
                        f"thumbnails/{video_id}.jpg",
                        'image/jpeg'
                    )
                    result['thumbnail'] = thumbnail_url
                
                # Create streaming variants
                variants = self.create_streaming_variants(video_path, temp_dir)
                
                # Upload variants to R2
                for quality, variant_path in variants.items():
                    variant_url = self.upload_to_r2(
                        variant_path,
                        f"videos/{video_id}_{quality}.mp4"
                    )
                    if variant_url:
                        result['variants'][quality] = variant_url
            
            result['status'] = 'completed'
            
        except Exception as e:
            result['status'] = 'failed'
            result['error'] = str(e)
            print(f"Video processing failed: {e}")
        
        return result

if __name__ == "__main__":
    # Test processing
    processor = VideoProcessor()
    
    # Example usage
    test_video = "/app/uploads/test_video.mp4"
    if os.path.exists(test_video):
        result = processor.process_video_complete(test_video, "test_123")
        print("Processing result:", json.dumps(result, indent=2))
