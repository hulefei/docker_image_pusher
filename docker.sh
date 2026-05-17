echo sync docker

# 设置环境变量
REGISTRY_USER="$1"  # 替换为实际值
REGISTRY_PASSWORD="$2"  # 替换为实际值
NAME_SPACE="$3"  # 替换为实际值
REGISTRY="$4"  # 替换为实际值

docker login -u "$REGISTRY_USER" -p "$REGISTRY_PASSWORD" "$REGISTRY"

# 定义处理镜像的逻辑
process_images() {
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
        image="${image%%@*}"

        # 解析镜像名（最后一段，含 tag）
        image_name_tag=$(echo "$image" | awk -F'/' '{print $NF}')

        # 保留除最后一段镜像名之外的全部 namespace 路径
        # 例如：
        #   nginx                                          -> namespace 为空
        #   nvidia/cuda:tag                                -> namespace = nvidia
        #   k8s.gcr.io/kube-state-metrics/xxx:tag          -> namespace = k8s.gcr.io/kube-state-metrics
        # 注意：会过滤掉常见的 registry 域名（含 . 或 :），避免出现非法的多级 host
        name_space=$(echo "$image" | awk -F'/' '{
            n = NF - 1
            if (n <= 0) { print ""; next }
            out = ""
            for (i = 1; i <= n; i++) {
                seg = $i
                # 跳过看起来像 registry host 的第一段（包含 . 或 :）
                if (i == 1 && (seg ~ /\./ || seg ~ /:/)) continue
                out = (out == "" ? seg : out "/" seg)
            }
            print out
        }')

        name_space_prefix=""
        [[ -n "$name_space" ]] && name_space_prefix="${name_space}/"

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
