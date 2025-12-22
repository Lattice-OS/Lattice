#!/usr/bin/env bash
set -euo pipefail

PKG_DIR="pkg"
OUT_FILE="$PKG_DIR/index.toml"

echo "Generating package index at $OUT_FILE"

# Sanity check: are we in a git repo?
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git repository"
    exit 1
fi

# Write header
cat > "$OUT_FILE" <<EOF
[repository]
name = "Lattice Official"
description = "Official Lattice package repository"

EOF

# DO NOT use GROUPS (it's a bash builtin)
declare -A PACKAGE_GROUPS=(
    ["kernel"]="packages.kernel"
    ["boot"]="packages.boot"
    ["shared"]="packages.shared"
    ["config"]="packages.config"
    ["services"]="packages.services"
    ["drivers/core"]="packages.drivers_core"
    ["drivers/mekanism"]="packages.drivers_mekanism"
)

for dir in "${!PACKAGE_GROUPS[@]}"; do
    group="${PACKAGE_GROUPS[$dir]}"
    full_path="$PKG_DIR/$dir"

    [[ -d "$full_path" ]] || continue

    echo "[$group]" >> "$OUT_FILE"

    find "$full_path" -type f -name "*.lua" | sort | while read -r file; do
        rel_path="${file#$PKG_DIR/}"
        name="$(basename "$file" .lua)"
        hash="$(sha256sum "$file" | awk '{print $1}')"

        cat >> "$OUT_FILE" <<EOF
$name = { path = "$rel_path", sha256 = "$hash" }
EOF
    done

    echo >> "$OUT_FILE"
done

echo "Package index generated."

# Stage changes
git add "$PKG_DIR"

# Check if there is anything to commit
if git diff --cached --quiet; then
    echo "No changes to commit."
    exit 0
fi

# Prompt for commit message
default_msg="Update package index"
read -r -p "Commit message [$default_msg]: " commit_msg
commit_msg="${commit_msg:-$default_msg}"

git commit -m "$commit_msg"

# Ask whether to push
read -r -p "Push to origin? [Y/n]: " push_ans
push_ans="${push_ans:-y}"

case "$push_ans" in
    [yY]|[yY][eE][sS])
        current_branch="$(git branch --show-current)"
        echo "Pushing to origin/$current_branch"
        git push origin "$current_branch"
        ;;
    *)
        echo "Skipping push."
        ;;
esac

echo "Done."
