"""PRQ routes."""
from __future__ import annotations

from fastapi import APIRouter

from app.schemas.prq_schemas import MRICalculationIn, MRICalculationOut
from app.services.mri_engine import mri_engine

router = APIRouter(prefix="/prq", tags=["prq"])


@router.post("/mri", response_model=MRICalculationOut)
async def calculate_mri(request: MRICalculationIn) -> MRICalculationOut:
    """Calculate MRI from raw readiness signals."""

    mri = mri_engine.calculate(arv=request.arv, esi=request.esi, pacing=request.pacing)
    return MRICalculationOut(mri=mri, grade=mri_engine.grade(mri))

