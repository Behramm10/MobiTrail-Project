import logging
import numpy as np
import cv2
from deepface import DeepFace
from app.database.config import Config

logger = logging.getLogger(__name__)

class FaceEngine:
    @staticmethod
    def extract_embedding(image_path: str) -> list[float] | None:
        """
        Extract the 512-dimensional ArcFace embedding vector from an image file.
        
        Returns:
            list[float]: The ArcFace embedding vector, or None if no face is detected.
        """
        try:
            logger.info(f"Extracting face embedding using ArcFace model for: {image_path}")
            
            # Extract representations (can detect multiple faces, but we enforce single face)
            representations = DeepFace.represent(
                img_path=image_path,
                model_name="ArcFace",
                detector_backend="opencv",
                enforce_detection=True
            )
            
            if representations and len(representations) > 0:
                embedding = representations[0]["embedding"]
                logger.info(f"✓ Feature extraction successful. Vector size: {len(embedding)}")
                return embedding
            else:
                logger.warning("No face region detected in the image.")
                return None
        except Exception as e:
            logger.error(f"✗ Face embedding extraction failed: {e}")
            return None

    @staticmethod
    def compute_similarity(embedding1: list[float], embedding2: list[float]) -> float:
        """
        Calculate the Cosine Similarity percentage between two ArcFace embedding vectors.
        
        Formula:
            Similarity = CosineSimilarity * 100
            Where CosineSimilarity = dot(A, B) / (||A|| * ||B||)
            
        Returns:
            float: Similarity score (typically between 0.0 and 100.0)
        """
        try:
            v1 = np.array(embedding1, dtype=np.float32)
            v2 = np.array(embedding2, dtype=np.float32)
            
            dot_product = np.dot(v1, v2)
            norm_v1 = np.linalg.norm(v1)
            norm_v2 = np.linalg.norm(v2)
            
            cosine_similarity = dot_product / (norm_v1 * norm_v2 + 1e-8)
            
            # Map cosine similarity to a percentage scale [0, 100]
            similarity_percentage = float(cosine_similarity * 100)
            
            logger.info(f"Similarity comparison: Cosine value = {cosine_similarity:.4f}, "
                        f"Percentage = {similarity_percentage:.2f}%")
            return similarity_percentage
        except Exception as e:
            logger.error(f"✗ Error computing cosine similarity: {e}")
            return 0.0
            
    @staticmethod
    def verify_face(live_image_path: str, stored_embedding: list[float]) -> tuple[bool, float, str]:
        """
        Extract the embedding of a live image and compare it with the stored embedding.
        
        Returns:
            tuple: (is_matched, similarity_score, message)
        """
        live_embedding = FaceEngine.extract_embedding(live_image_path)
        if not live_embedding:
            return False, 0.0, "No face detected in the verification capture."
            
        similarity_score = FaceEngine.compute_similarity(live_embedding, stored_embedding)
        is_matched = similarity_score >= Config.VERIFICATION_THRESHOLD
        
        if is_matched:
            msg = f"Face verified successfully ({similarity_score:.1f}% Match)"
        else:
            msg = f"Face verification failed ({similarity_score:.1f}% Match < {Config.VERIFICATION_THRESHOLD}%)"
            
        return is_matched, similarity_score, msg
