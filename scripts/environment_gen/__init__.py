"""Final Evolution Lab - Generative World Model Environment Pipeline.

Integrates Gaia-style generative world models (Stable Video Diffusion,
Runway Gen-3, Luma Dream Machine) to produce dynamic 2.5D training
environments from text prompts.

Architecture:
  Text Prompt -> Generative Model API -> Video/Image -> Skybox Conversion
  -> UE5 Dynamic Texture -> 2.5D Backdrop Rendering

The generative model provides VISUAL SKINS only; all physics, animation,
and gameplay logic remain in UE5.
"""

__version__ = "2.0.0"
__pipeline__ = "generative-environment"
__openart_integration__ = True
