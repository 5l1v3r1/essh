local docker = {}

docker.driver = function()
    t = [=[
{{if .Task.IsRemoteTask}}
echo "[error] docker driver engine supports only running a local task."
exit 1
{{end}}

{{if ne .Task.Context.TypeString "WorkingData"}}
echo "[error] docker driver engine supports only running a task that is defined per-project configuration."
exit 1
{{end}}

__essh_var_status=0
echo 'Starting task by using docker driver engine.'
echo "Checking docker version."
docker version
__essh_var_status=$?
if [ $__essh_var_status -ne 0 ]; then
    echo "[error] got a error when it checks the docker environment. exited with $__essh_var_status."
    exit $__essh_var_status
fi

echo ""

__essh_var_docker_working_dir=$(pwd)
__essh_var_docker_image={{if .Driver.Props.image}}{{.Driver.Props.image | ShellEscape}}{{end}}
__essh_var_docker_build="{{if .Driver.Props.build}}1{{end}}"
__essh_var_docker_build_url={{if .Driver.Props.build.url}}{{.Driver.Props.build.url | ShellEscape}}{{end}}
__essh_var_docker_build_dockerfile={{if .Driver.Props.build.dockerfile}}{{.Driver.Props.build.dockerfile | ShellEscape}}{{end}}

if [ -z "$__essh_var_docker_image" ]; then
    echo "[error] docker driver engine requires 'image' config."
    exit 1
fi

# checks existence of the image
echo "Using image '$__essh_var_docker_image'"
if [ -z $(docker images -q $__essh_var_docker_image) ]; then
    # There is not the image in the host.
    if [ -n "$__essh_var_docker_build" ]; then
        echo "There is not the image '$__essh_var_docker_image' in the running machine."
        echo "Building a docker image '$__essh_var_docker_image'..."

        if [ -n "$__essh_var_docker_build_url" ]; then
            echo "docker build -t $__essh_var_docker_image $__essh_var_docker_build_url"
            docker build -t $__essh_var_docker_image $__essh_var_docker_build_url
            __essh_var_status=$?
            if [ $__essh_var_status -ne 0 ]; then
                echo "[error] got a error in docker build."
                exit $__essh_var_status
            fi
        elif [ -n "$__essh_var_docker_build_dockerfile" ]; then
            echo "docker build -t $__essh_var_docker_image -"

            # note: double quote is needed to output multi lines
            echo "$__essh_var_docker_build_dockerfile" | docker build -t $__essh_var_docker_image -
            __essh_var_status=$?
            if [ $__essh_var_status -ne 0 ]; then
                echo "[error] got a error in docker build."
                exit $__essh_var_status
            fi
        else
            echo "[error] got a error in docker build. require 'url' or 'dockerfile'"
            exit 1
        fi
    fi
fi

# create runfile
__essh_var_docker_runfilename=run.$$.sh
__essh_var_docker_runfile={{.Task.Context.TmpDir}}/$__essh_var_docker_runfilename
touch $__essh_var_docker_runfile
chmod 755 $__essh_var_docker_runfile

# input content to the runfile.
cat << 'EOF-ESSH-DOCKER_SCRIPT' > $__essh_var_docker_runfile

__essh_var_status=0
{{range $i, $script := .Scripts}}
if [ $__essh_var_status -eq 0 ]; then
{{$script.code}}
__essh_var_status=$?
fi
{{end}}
exit $__essh_var_status

EOF-ESSH-DOCKER_SCRIPT

# echo "Created temprary runfile '$__essh_var_docker_runfile'"

echo "Running task in the docker container..."
docker run \
    -v ${__essh_var_docker_working_dir}:/essh \
    -w /essh \
    $__essh_var_docker_image \
    sh ./.essh/tmp/$__essh_var_docker_runfilename --docker-run
__essh_var_status=$?

# delete runfile
rm "$__essh_var_docker_runfile"

echo "Removing tarminated containers."
docker rm `${sudo}docker ps -a -q`

echo "Task exited with $__essh_var_status."
exit $__essh_var_status
]=]

    return t
end

return docker