echo sync docker

# 设置环境变量
REGISTRY_USER="$1"  # 替换为实际值
REGISTRY_PASSWORD="$2"  # 替换为实际值
NAME_SPACE="$3"  # 替换为实际值
REGISTRY="$4"  # 替换为实际值

docker login -u "$REGISTRY_USER" -p "$REGISTRY_PASSWORD" "$REGISTRY"

# 定义处理镜像的逻辑
process_images() {
    declare -A duplicate_images
    declare -A temp_map

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" ]] && continue
        if echo "$line" | grep -q '^\s*#'; then
            continue
        fi

        image=$(echo "$line" | awk '{print $NF}')
        image="${image%%@*}"

        image_name_tag=$(echo "$image" | awk -F'/' '{print $NF}')
        name_space=$(echo "$image" | awk -F'/' '{if (NF==3) print $2; else if (NF==2) print $1; else print ""}')
        name_space="${name_space}_"
        image_name=$(echo "$image_name_tag" | awk -F':' '{print $1}')

        if [[ -n "${temp_map[$image_name]}" ]]; then
            if [[ "${temp_map[$image_name]}" != "$name_space" ]]; then
                duplicate_images["$image_name"]="true"
            fi
        else
            temp_map["$image_name"]="$name_space"
        fi
    done < images.txt

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" ]] && continue
        if echo "$line" | grep -q '^\s*#'; then
            continue
        fi

        echo "Pulling image: $line"
        docker pull "$line"

        platform=$(echo "$line" | awk -F'--platform[ =]' '{if (NF>1) print $2}' | awk '{print $1}')
        platform_prefix=""
        [[ -n "$platform" ]] && platform_prefix="${platform//\//_}_"

        image=$(echo "$line" | awk '{print $NF}')
        image_name_tag=$(echo "$image" | awk -F'/' '{print $NF}')
        name_space=$(echo "$image" | awk -F'/' '{if (NF==3) print $2; else if (NF==2) print $1; else print ""}')
        image_name=$(echo "$image_name_tag" | awk -F':' '{print $1}')

        name_space_prefix=""
        if [[ -n "${duplicate_images[$image_name]}" && -n "$name_space" ]]; then
            name_space_prefix="${name_space}_"
        fi

        image_name_tag="${image_name_tag%%@*}"
        new_image="$REGISTRY/$NAME_SPACE/$platform_prefix$name_space_prefix$image_name_tag"

        echo "Tagging image: $image -> $new_image"
        docker tag "$image" "$new_image"

        echo "Pushing image: $new_image"
        docker push "$new_image"

#        echo "Cleaning up images..."
#        docker rmi "$image"
#        docker rmi "$new_image"
#        echo "Disk space after cleanup:"
#        echo "=============================================================================="
#        df -hT
#        echo "=============================================================================="
    done < images.txt
}

# 执行处理镜像逻辑
process_images
