from pathlib import Path

from setuptools import find_packages, setup


ROOT = Path(__file__).parent


setup(
    name="lightweight-agentic-coding",
    version="0.1.0",
    description="lac - Lightweight Agentic Coding CLI. Profile management, runtime lifecycle, and provider orchestration for local AI.",
    long_description=(ROOT / "README.md").read_text(encoding="utf-8"),
    long_description_content_type="text/markdown",
    license="MIT",
    license_files=["LICENSE", "THIRD_PARTY_NOTICES.md"],
    author="Lightweight Agentic Coding contributors",
    url="https://github.com/TuukkaTanner/lightweight-agentic-coding",
    keywords=[
        "agentic-coding",
        "llama.cpp",
        "opencode",
        "local-ai",
        "apple-silicon",
        "ds4",
    ],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: MacOS",
        "Operating System :: Microsoft :: Windows",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: 3.13",
        "Topic :: Software Development",
        "Topic :: System :: Systems Administration",
    ],
    project_urls={
        "Homepage": "https://github.com/TuukkaTanner/lightweight-agentic-coding",
        "Repository": "https://github.com/TuukkaTanner/lightweight-agentic-coding",
        "Issues": "https://github.com/TuukkaTanner/lightweight-agentic-coding/issues",
        "Changelog": "https://github.com/TuukkaTanner/lightweight-agentic-coding/blob/main/CHANGELOG.md",
        "Documentation": "https://github.com/TuukkaTanner/lightweight-agentic-coding/tree/main/docs",
    },
    python_requires=">=3.10",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    package_data={"lac": ["data/*", "data/**/*", "data/**/**/*", "data/**/**/**/*", "data/**/**/**/**/*"]},
    include_package_data=True,
    entry_points={"console_scripts": ["lac=lac.cli:main"]},
)
