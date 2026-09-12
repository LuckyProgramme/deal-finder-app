"""Development server launcher for Deal Finder FastAPI backend."""

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "deal_finder.api.app:app",
        host="127.0.0.1",
        port=8000,
        reload=True,
    )
