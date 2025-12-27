#!/bin/bash

set -e

# Configuration
DOCKER_USERNAME="pablor21"
IMAGE_NAME="postgis"
PLATFORMS="linux/amd64,linux/arm64"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== PostGIS Docker Build Script ===${NC}"
echo ""

# Check if git repo exists
if [ ! -d .git ]; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Get latest git tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LATEST_TAG" ]; then
    echo -e "${YELLOW}No git tags found. Using 'latest' only.${NC}"
    TAGS=("${DOCKER_USERNAME}/${IMAGE_NAME}:latest")
else
    echo -e "${GREEN}Latest git tag: ${LATEST_TAG}${NC}"
    
    # Remove 'v' prefix if exists
    VERSION=${LATEST_TAG#v}
    
    # Extract major.minor version (e.g., 1.0 from 1.0.0)
    MAJOR_MINOR=$(echo $VERSION | cut -d. -f1-2)
    
    # Build tag array
    TAGS=(
        "${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
        "${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
        "${DOCKER_USERNAME}/${IMAGE_NAME}:${MAJOR_MINOR}"
        "${DOCKER_USERNAME}/${IMAGE_NAME}:pg18-postgis3.6"
    )
fi

# Display tags that will be created
echo ""
echo -e "${GREEN}Tags to be created:${NC}"
for tag in "${TAGS[@]}"; do
    echo "  - $tag"
done
echo ""

# Confirm before building
read -p "Continue with build and push? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Build cancelled.${NC}"
    exit 0
fi

# Check if logged in to Docker Hub
echo ""
echo -e "${GREEN}Checking Docker Hub authentication...${NC}"
if ! docker info 2>/dev/null | grep -q "Username: ${DOCKER_USERNAME}"; then
    echo -e "${YELLOW}Not logged in to Docker Hub. Logging in...${NC}"
    docker login
fi

# Check if buildx builder exists
echo ""
echo -e "${GREEN}Setting up Docker buildx...${NC}"
if ! docker buildx inspect multiarch >/dev/null 2>&1; then
    echo "Creating buildx builder 'multiarch'..."
    docker buildx create --name multiarch --driver docker-container --use
    docker buildx inspect --bootstrap
else
    echo "Using existing buildx builder 'multiarch'..."
    docker buildx use multiarch
fi

# Build tag arguments
TAG_ARGS=""
for tag in "${TAGS[@]}"; do
    TAG_ARGS="$TAG_ARGS -t $tag"
done

# Build and push
echo ""
echo -e "${GREEN}Building and pushing multi-architecture image...${NC}"
echo -e "${YELLOW}This may take 15-25 minutes for both architectures...${NC}"
echo ""

docker buildx build \
    --platform $PLATFORMS \
    $TAG_ARGS \
    --push \
    .

echo ""
echo -e "${GREEN}=== Build Complete! ===${NC}"
echo ""
echo -e "${GREEN}Images pushed to Docker Hub:${NC}"
for tag in "${TAGS[@]}"; do
    echo "  ✓ $tag"
done
echo ""
echo -e "${GREEN}Pull your image with:${NC}"
echo "  docker pull ${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
echo ""