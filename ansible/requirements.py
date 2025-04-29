# requirements.py

prod = ["ansible", "passlib"]

extras = {
    "test": ["pytest", "pytest-cov"],
    "lint": ["flake8", "black", "mypy"],
    "docs": ["mkdocs", "mkdocstrings"],
}

dev = prod + extras["test"] + extras["lint"] + extras["docs"]
