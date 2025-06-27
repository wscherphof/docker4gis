#!/bin/bash

# Do not echo commands just yet, to prevent printing the PAT to the console.
# [ -n "$DEBUG" ] && set -x

project=$1
if [ "$project" = -p ] || [ "$project" = --project ]; then
    SYSTEM_TEAMPROJECT=${2:?Project name is required}
    shift 2
# If project starts with --project=, then extract the value.
elif [[ $project =~ ^--project= ]]; then
    SYSTEM_TEAMPROJECT=${project#--project=}
    shift
fi

set_env() {
    local name=$1
    local message=$2
    local default=$3

    # Read current value from env_file if it exists
    current_value=""
    if [ -f /devops/env_file ]; then
        # shellcheck source=/dev/null
        source /devops/env_file
        current_value=${!name}
    fi

    # Use current value from env_file as default, or fall back to provided
    # default
    if [ -n "$current_value" ]; then
        if [ "$name" = PAT ]; then
            default="***"
        else
            default="$current_value"
        fi
        default_type="current"
    else
        default="$3"
        default_type="default"
    fi

    [ -n "$default" ] && message+=" (Enter for $default_type: $default)"

    # Always ask to provide the value, using current/provided default
    while true; do
        if [ "$name" = PAT ]; then
            # Do not echo the value entered.
            read -rsp "$message : " input_value
            echo
        else
            read -rp "$message : " input_value
        fi

        # Use current value if no input and no explicit default, otherwise use
        # explicit default
        if [ -z "$input_value" ]; then
            if [ -n "$3" ]; then
                value="$3"
            else
                value="$current_value"
            fi
        else
            value="$input_value"
        fi

        [ -n "$value" ] && break
    done

    if [ "$name" = SYSTEM_TEAMPROJECT ]; then
        # Assign the value to the variable.
        SYSTEM_TEAMPROJECT=$value
    else
        # Call the set.sh script to save the value to the env_file. Since set.sh
        # may amend the value given, we read the env_file back in later, to get
        # the proper value for each variable.
        /devops/set.sh "$name" "$value"
    fi
}

set_env SYSTEM_TEAMPROJECT \
    "DevOps Project" \
    "$DOCKER_USER"

export SYSTEM_TEAMPROJECT

# Read current values from file.
# shellcheck source=/dev/null
source /devops/env_file

doc_url="https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&toc=%2Fazure%2Fdevops%2Forganizations%2Ftoc.json&tabs=Windows#create-a-pat"
message="Personal Access Token (full access, incl. project creation)"
set_env PAT \
    "$message - see $doc_url"

set_env DEFAULT_POOL \
    "Pipeline Agent Pool for general jobs" \
    "$DEVOPS_DEFAULT_POOL"

set_env VPN_POOL \
    "Pipeline Agent Pool for deployment jobs" \
    "$DEVOPS_VPN_POOL"

set_env DOCKER_REGISTRY \
    "Docker Registry" \
    "$DEVOPS_DOCKER_REGISTRY"

set_env SYSTEM_COLLECTIONURI \
    "DevOps Organisation" \
    "$DEVOPS_ORGANISATION"

# Read altered values from file.
# shellcheck source=/dev/null
source /devops/env_file

# Login to the Azure DevOps CLI.
export AZURE_DEVOPS_EXT_PAT=$PAT

# Replace string to insert the \"\$PAT@\" value between the (https):// and the
# host name in the URI (e.g. https://dev.azure.com/merkatordev/).
AUTHORISED_COLLECTION_URI=${SYSTEM_COLLECTIONURI/'://'/'://'$PAT@}
export AUTHORISED_COLLECTION_URI

if [ -z "$DEBUG" ]; then
    log() {
        echo '• ' "$@"
        sleep 1
    }
else
    log() {
        set +x
        echo '---------------------------------------------------------------------'
        echo "$@"
        echo '---------------------------------------------------------------------'
        # Prevent next commands echoing sooner.
        sleep 1
        set -x
    }
fi
export -f log

log Setup

# Set the default project and organisation for the Azure DevOps CLI.
az devops configure --defaults "organization=$SYSTEM_COLLECTIONURI"
az devops configure --defaults "project=$SYSTEM_TEAMPROJECT"

# Configure git identity.
git config --global user.email 'pipeline@azure.com'
git config --global user.name 'Azure Pipeline'

# Set the default branch name to 'main', to prevent git from printing hints to
# the console.
git config --global init.defaultBranch main

get_project_id() {
    SYSTEM_TEAMPROJECTID=$(az devops project show \
        --project "$SYSTEM_TEAMPROJECT" \
        --query id \
        --output tsv)
    export SYSTEM_TEAMPROJECTID
    [ -n "$SYSTEM_TEAMPROJECTID" ]
}

# Get the project id (create the project if it doesn't exist). Exit on failure.
if get_project_id &>/dev/null; then
    log "Project $SYSTEM_TEAMPROJECT exists"
else
    log "Create Project $SYSTEM_TEAMPROJECT"
    # 2>/dev/null to prevent printing of harmless ERROR: VS800075: The project
    # with id 'vstfs:///Classification/TeamProject/f5e...87' does not exist, or
    # you do not have permission to access it.
    response=$(az devops project create --name "$SYSTEM_TEAMPROJECT" \
        2>/dev/null)
    # Make DevOps realise the new project exists.
    sleep 5
    default_repository_id_to_delete=$(
        az repos show --repository "$SYSTEM_TEAMPROJECT" --query id --output tsv
    ) &&
        get_project_id
fi || exit

log Check Project Administrators group membership

project_administrators_group=$(
    az devops security group list \
        --query "(graphGroups[?displayName=='Project Administrators'])[0]"
) &&
    descriptor=$(
        node --print "($project_administrators_group).descriptor"
    ) &&
    members=$(
        az devops security group membership list --id "$descriptor"
    ) &&
    me=$(
        /devops/rest.sh vssps GET profile/profiles/me
    ) &&
    email_address=$(
        node --print "($me).emailAddress"
    ) &&
    is_member=$(
        node --print "Object.values(($members)).some(m =>
            m.principalName === '$email_address' ||
            m.mailAddress === '$email_address'
        )"
    ) &&
    [ "$is_member" = true ] || exit

policy_exempt() {
    local allow_deny=$1

    # This value was set in the group membership check above.
    local project_administrators_group=$project_administrators_group

    policy_exemt_originId=${policy_exemt_originId:-$(
        node --print "($project_administrators_group).originId"
    )} &&
        policy_exemt_identity=${policy_exemt_identity:-$(
            /devops/rest.sh vssps GET identities \
                "identityIds=$policy_exemt_originId"
        )} &&
        policy_exemt_descriptor=${policy_exemt_descriptor:-$(
            node --print "($policy_exemt_identity).value[0].descriptor"
        )} &&
        /devops/set_permissions.sh 'Project Administrators' \
            "$policy_exemt_descriptor" "$allow_deny" PolicyExempt
}

# Steps to create a repo named $REPOSITORY.
create_repository() {

    log "Create repository $REPOSITORY" &&
        REPOSITORY_ID=$(az repos create --name "$REPOSITORY" \
            --query=id --output tsv) || return

    export REPOSITORY_ID

    log "Initialise repository $REPOSITORY" &&
        (
            temp=$(mktemp --directory) &&
                cd "$temp" &&
                git init &&
                git commit --allow-empty -m "initialise repository" &&
                git branch -m main &&
                /devops/git_origin.sh remote add origin &&
                git push origin main
        ) || return

    log "Update repository $REPOSITORY: set default branch to 'main'" &&
        response=$(az repos update --repository="$REPOSITORY" \
            --default-branch main) || return
}

# Clone the repo $REPOSITORY.
git_clone() {
    log "Clone $REPOSITORY" &&
        mkdir -p ~/"$SYSTEM_TEAMPROJECT" &&
        cd ~/"$SYSTEM_TEAMPROJECT" &&
        /devops/git_origin.sh clone
}

# Create a docker4gis component for the repo $REPOSITORY.
dg_init_component() {
    log "dg init/component $COMPONENT in $REPOSITORY" &&
        cd ~/"$SYSTEM_TEAMPROJECT/$REPOSITORY" &&
        if [ "$REPOSITORY" = ^package ]; then
            dg init "$DOCKER_REGISTRY"
        else
            dg component "$COMPONENT"
        fi || return

    log "Push $REPOSITORY changes" &&
        git add . &&
        git commit -m "docker4gis init/component" &&
        git push origin
}

# Create the Environments, each with an Approval check, and an SSH Service
# Connection. Do this before creating any pipelines referencing the
# environments, because that will create them automatically, and in a state that
# prevents us from adding the approval checks.
for environment in TEST PRODUCTION; do
    /devops/environment.sh "$environment" || exit
done

# Get the Variable Group id (create the Variable Group if it doesn't exist),
# which is needed for creating the Pipelines.
VARIABLE_GROUP_ID=$(az pipelines variable-group list \
    --query "[?name=='docker4gis'].id" \
    --output tsv)
if [ -n "$VARIABLE_GROUP_ID" ]; then
    log "Variable Group docker4gis exists"
else
    log Create variable group &&
        VARIABLE_GROUP_ID=$(az pipelines variable-group create \
            --name "docker4gis" \
            --authorize true \
            --variables "DOCKER_PASSWORD=changeit" \
            --query=id) || exit

    log Make variable DOCKER_PASSWORD secret &&
        response=$(az pipelines variable-group variable update \
            --group-id "$VARIABLE_GROUP_ID" \
            --name DOCKER_PASSWORD \
            --secret true) || exit
fi
export VARIABLE_GROUP_ID

# ------------------------------------------------------------------------------
# Begin of the main loop over the components.
# ------------------------------------------------------------------------------

# Add required components to the ones provided as arguments.
components=(^package proxy "$@")
# Make components lowercase.
components=("${components[@],,}")

log Components: "${components[@]}"

# Temporarily allow "Bypass policies when pushing" for "Project Administrators".
policy_exempt allow || exit

# Create the repositories, components, and pipelines.
for component_repository in "${components[@]}"; do

    # Split component_repository into component and repository, using = as the
    # separator.
    IFS='=' read -r COMPONENT REPOSITORY <<<"$component_repository"
    # shellcheck disable=SC2269
    {
        # Just to see the values in the log.
        component_repository="$component_repository"
        COMPONENT=$COMPONENT
        REPOSITORY=$REPOSITORY
    }
    REPOSITORY=${REPOSITORY:-$COMPONENT}
    export COMPONENT REPOSITORY

    repository_result=0

    # Skip if the repository already exists.
    if az repos show --repository "$REPOSITORY" &>/dev/null; then
        log "Repository $REPOSITORY already exists"
        # Need the package directory for creating other components.
        [ "$REPOSITORY" = ^package ] && git_clone
        continue
    fi

    # Create the repository, its docker4gis component, and its pipelines.
    create_repository &&
        git_clone &&
        dg_init_component &&
        /devops/pipelines.sh

    repository_result=$?
    [ "$repository_result" = 0 ] || {
        log "Error: non-zero repository_result: $repository_result"
        break
    }
done

# Undo temporarily allow "Bypass policies when pushing" for "Project
# Administrators".
policy_exempt deny || exit

# Exit if any repository creation failed - but only after undoing the policy
# change.
[ "$repository_result" = 0 ] || {
    log "Error: non-zero repository_result: $repository_result"
    exit "$repository_result"
}

# ------------------------------------------------------------------------------
# End of the main loop over the components.
# ------------------------------------------------------------------------------

# Delete the default repository, if we created a new project.
if [ -n "$default_repository_id_to_delete" ]; then
    log "Delete default repository $SYSTEM_TEAMPROJECT"
    response=$(az repos delete --yes --id "$default_repository_id_to_delete")
fi || exit

# Create a cross-repository policy (if it doesn't exist) to require all PR
# comments to be roseolved before merging.
comment_requirements_policy='{
  "isBlocking": true,
  "isDeleted": false,
  "isEnabled": true,
  "isEnterpriseManaged": false,
  "revision": 1,
  "settings": {
      "scope": [
          {
              "matchKind": "Exact",
              "refName": "refs/heads/main",
              "repositoryId": null
          }
      ]
  },
  "type": {
      "displayName": "Comment requirements",
      "id": "c6a1889d-b943-4856-b76f-9e46bb6b0df2"
  }
}'
policy_query="[?settings.scope[0].repositoryId==null]"
policy_query+=" | [?type.displayName=='Comment requirements'].id"
existing_policy=$(az repos policy list --output tsv --query "$policy_query")
if [ -n "$existing_policy" ]; then
    log "Policy Comment requirements exists"
else
    log "Create Policy Comment requirements"
    response=$(/devops/rest.sh project POST policy/configurations '' \
        "$comment_requirements_policy")
fi || exit

# Set permissions for the Project Build Service.
project_build_service_identity=$(/devops/rest.sh vssps GET identities \
    "searchFilter=AccountName&filterValue=$SYSTEM_TEAMPROJECTID") &&
    project_build_service_descriptor=$(node --print \
        "($project_build_service_identity).value[0].descriptor") &&
    /devops/set_permissions.sh 'Project Build Service' \
        "$project_build_service_descriptor" allow \
        GenericRead GenericContribute CreateTag PolicyExempt || exit

# Try to create the Agent Pool if it doesn't exist in the project.
create_pool() {
    local pool_name=$1
    local queueNames
    queueNames=$(node --print "encodeURIComponent('$pool_name')") &&
        local queues &&
        queues=$(/devops/rest.sh project GET distributedtask/queues \
            "queueNames=$queueNames") &&
        if [ "$(node --print "($queues).count")" -gt 0 ]; then
            log Agent Pool "$pool_name" exists in project
        else
            local query="[?name=='$pool_name'].id"
            local pool_id
            if pool_id=$(az pipelines pool list --output tsv --query "$query"); then
                local response
                if response=$(/devops/rest.sh project POST \
                    distributedtask/queues authorizePipelines=true "{
                        \"name\": \"$pool_name\",
                        \"pool\": {
                            \"id\": $pool_id
                        }
                    }"); then
                    log Agent Pool "$pool_name" added to project
                else
                    log Error: failed to add Agent Pool "$pool_name" to project
                    return 1
                fi
            else
                log Error: pool "$pool_name" not found
                return 1
            fi
        fi

    permit_pool "$pool_name" "$pool_id"
}

# Grant permission for the project to use the specified agent pool.
permit_pool() {
    local pool_name=$1
    local pool_id=$2

    log "Grant permission to use Agent Pool $pool_name"

    # Get the queue ID from the project's queues
    local queueNames
    queueNames=$(node --print "encodeURIComponent('$pool_name')")
    local queues
    queues=$(/devops/rest.sh project GET distributedtask/queues \
        "queueNames=$queueNames")

    local queue_count
    queue_count=$(node --print "($queues).count" 2>/dev/null)

    if [ "$queue_count" != "1" ]; then
        log "Error: Expected 1 queue for pool '$pool_name', found $queue_count"
        return 1
    fi

    local queue_id
    queue_id=$(node --print "($queues).value[0].id" 2>/dev/null)

    if [ -z "$queue_id" ]; then
        log "Error: Could not get queue ID for pool '$pool_name'"
        return 1
    fi

    # Get all pipelines that need permission to use this pool
    local pipelines
    pipelines=$(az pipelines list --query "[].{id:id}" --output json 2>/dev/null) || {
        log "Error: Could not get pipelines list, skipping agent pool permission grant"
        return 1
    }

    if [ -z "$pipelines" ] || [ "$pipelines" = "[]" ]; then
        log "No pipelines found, skipping agent pool permission grant"
        return 0
    fi

    # Create the pipeline permissions payload that matches the web UI request
    local pipeline_permissions
    pipeline_permissions=$(node --print "
        try {
            const pipelines = $pipelines;
            const permissions = {
                pipelines: pipelines.map(p => ({
                    id: p.id,
                    authorized: true
                }))
            };
            JSON.stringify(permissions);
        } catch (e) {
            console.log('{}');
        }
    " 2>/dev/null)

    if [ -z "$pipeline_permissions" ] || [ "$pipeline_permissions" = "{}" ]; then
        log "Error: Could not format pipeline permissions"
        return 1
    fi

    local response
    if response=$(/devops/rest.sh project PATCH \
        "pipelines/pipelinePermissions/queue/$queue_id" '' \
        "$pipeline_permissions"); then
        return 0
    else
        log "Error: Failed to grant pipeline permissions for Agent Pool '$pool_name'"
        echo "- API Response: $response"
        echo "- Queue ID: $queue_id"
        echo "- Pipeline Permissions JSON: $pipeline_permissions"
        return 1
    fi
}

# Create agent pools and grant permissions (after all pipelines have been
# created)
create_pool "$DEFAULT_POOL" || exit
create_pool "$VPN_POOL" || exit

# We use `response=$(...)` to prevent the resonse from being echoed to the
# console.
response=${response:-}

log OK
