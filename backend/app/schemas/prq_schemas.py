"""PRQ/MRI schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field


class PRQProfileOut(BaseModel):
    """Readiness profile response."""

    user_id: str = Field(description="User id")
    overall_score: float = Field(description="Current Physical Readiness Quotient")
    grade: str = Field(description="Human-readable PRQ grade")


class MRICalculationIn(BaseModel):
    """Mental Resiliency Index inputs."""

    arv: float = Field(ge=0, le=100, description="Adaptive recovery value")
    esi: float = Field(ge=0, le=100, description="Emotional stability index")
    pacing: float = Field(ge=0, le=100, description="Pacing score")


class MRICalculationOut(BaseModel):
    """Mental Resiliency Index output."""

    mri: float = Field(description="0-100 MRI")
    grade: str = Field(description="MRI grade label")

