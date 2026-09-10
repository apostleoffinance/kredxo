from fastapi import APIRouter

router = APIRouter(tags=["positions"])


@router.get("/api/positions/{wallet}")
def get_positions(wallet: str) -> dict:
    return {"wallet": wallet.lower(), "positions": []}
