#!/bin/bash
# This script is inspried by https://github.com/pirsoscom/mcm_install_roks

# Export the vars in .env into your shell:
set -a
[[ -f ./.env ]] && source ./.env
[[ -f ./variable.sh ]] && source ./variable.sh

set -x

# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Do Not Edit Below
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo " ${CYAN} Cloud Pak for Multicloud Management${Cyan}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "  "
echo " ${CYAN} Install MCM for OpenShift 4.3 on IBM Cloud online${Cyan}"
echo "  "
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "  "
echo "  "
echo "  "


# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# PREREQUISITES
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "${CYAN}***************************************************************************************************************************${NC}"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${PURPLE} Getting MCM Inception Container - ${ORANGE}This may take some time"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"

        docker login "$ENTITLED_REGISTRY" -u "$ENTITLED_REGISTRY_USER" -p "$ENTITLED_REGISTRY_KEY"

        DOCKER_PULL=$(docker pull $ENTITLED_REGISTRY/cp/icp-foundation/mcm-inception:$MCM_INCEPTION_VERSION 2>&1)
        #echo $DOCKER_PULL

        if [[ $DOCKER_PULL =~ "pull access denied" ]];
        then
          echo "${RED}ERROR${NC}: Not entitled for Registry or not reachable"
          echo "${RED}${cross}  Installation Aborted${NC}"
          exit 1
        fi
        echo "    ${GREEN}  OK${NC}"
        echo "  "
        
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${CYAN}***************************************************************************************************************************${NC}"
echo "  "
echo "  "
echo "  "
echo "  "



echo "${CYAN}***************************************************************************************************************************${NC}"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${PURPLE}${wrench} Running Prerequisites${NC}"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"


        echo " ${wrench} Create Config Directory"
          rm -r $INSTALL_PATH/* 
          mkdir -p $INSTALL_PATH 
          cd $INSTALL_PATH
        echo "    ${GREEN}  OK${NC}"
        echo "  "
        

        echo " ${wrench} Patching Route, creating openshift image registry route for external access"
          oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}' 2>&1
        echo "    ${GREEN}  OK${NC}"
        echo "  "
        
        echo " ${wrench} Create Secret for Registry"
          #docker login "$ENTITLED_REGISTRY" -u "$ENTITLED_REGISTRY_USER" -p "$ENTITLED_REGISTRY_KEY"
          oc create secret docker-registry entitled-registry --docker-server=$ENTITLED_REGISTRY --docker-username=$ENTITLED_REGISTRY_USER --docker-password=$ENTITLED_REGISTRY_KEY --docker-email=admin@ibm.com
        echo "    ${GREEN}  OK${NC}"
        echo "  "
        
        echo " ${wrench} Creating config file"
          docker run --rm -v $(pwd):/data:z -e LICENSE=accept --security-opt label:disable $ENTITLED_REGISTRY/cp/icp-foundation/mcm-inception:$MCM_INCEPTION_VERSION cp -r cluster /data
        echo "    ${GREEN}  OK${NC}"
        echo "  "
        

        echo " ${wrench} Copy kubeconfig"
          oc config view > cluster/kubeconfig
        echo "    ${GREEN}  OK${NC}"
        echo "  "
        
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${CYAN}***************************************************************************************************************************${NC}"
echo "  "
echo "  "
echo "  "
echo "  "




# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Labeling some Stuff
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
echo "${CYAN}***************************************************************************************************************************${NC}"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${PURPLE}${memo} Labeling some Stuff${NC}"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"

        echo " ${wrench} Labeling worker node for cloudpak"
        oc label node $MASTER_COMPONENTS node-role.kubernetes.io/compute=true
        oc label node $PROXY_COMPONENTS node-role.kubernetes.io/compute=true
        oc label node $MANAGEMENT_COMPONENTS node-role.kubernetes.io/compute=true
        sleep 0.5
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${CYAN}***************************************************************************************************************************${NC}"
echo "  "
echo "  "
echo "  "
echo "  "


echo "${CYAN}***************************************************************************************************************************${NC}"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${PURPLE}${telescope} Creating config file${NC}"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"


        cd $INSTALL_PATH

        # ---------------------------------------------------------------------------------------------------------------------------------------------------"
        # Backup vanilla config
        # ---------------------------------------------------------------------------------------------------------------------------------------------------"
        cp cluster/config.yaml cluster/config.yaml.vanilla


        # ---------------------------------------------------------------------------------------------------------------------------------------------------"
        # Adapt Config FIle
        # ---------------------------------------------------------------------------------------------------------------------------------------------------"
        ${SED} -i "s/<your-openshift-dedicated-node-to-deploy-master-components>/$MASTER_COMPONENTS/" cluster/config.yaml
        ${SED} -i "s/<your-openshift-dedicated-node-to-deploy-proxy-components>/$PROXY_COMPONENTS/" cluster/config.yaml
        ${SED} -i "s/<your-openshift-dedicated-node-to-deploy-management-components>/$MANAGEMENT_COMPONENTS/" cluster/config.yaml

        ${SED} -i "s/<storage class available in OpenShift>/$STORAGE_CLASS_BLOCK/" cluster/config.yaml
        ${SED} -i "/^# elasticsearch_storage_class:/celasticsearch_storage_class: $STORAGE_CLASS_BLOCK" cluster/config.yaml

        ${SED} -i "s/notary: disabled/notary: enabled/" cluster/config.yaml
        ${SED} -i "s/cis-controller: disabled/cis-controller: enabled/" cluster/config.yaml
        ${SED} -i "s/mutation-advisor: disabled/mutation-advisor: enabled/" cluster/config.yaml
        ${SED} -i "s/vulnerability-advisor: disabled/vulnerability-advisor: enabled/" cluster/config.yaml
        ${SED} -i "s/licensing: disabled/licensing: enabled/" cluster/config.yaml
        ${SED} -i "s/audit-logging: disabled/audit-logging: enabled/" cluster/config.yaml
        ${SED} -i "s/logging: disabled/logging: enabled/" cluster/config.yaml
        ${SED} -i "s/image-security-enforcement: disabled/image-security-enforcement: enabled/" cluster/config.yaml


        echo "image_repo: $ENTITLED_REGISTRY/cp/icp-foundation"  >> cluster/config.yaml
        echo "private_registry_enabled: true"  >> cluster/config.yaml
        echo "docker_username: $ENTITLED_REGISTRY_USER"  >> cluster/config.yaml
        echo "docker_password: $ENTITLED_REGISTRY_KEY"  >> cluster/config.yaml



        echo "default_admin_password: $MCM_PWD" >> cluster/config.yaml
        echo "password_rules:" >> cluster/config.yaml
        echo "- '(.*)'" >> cluster/config.yaml

        if [[ $CLUSTER_NAME =~ "appdomain.cloud" ]];
        then
          echo " ${GREEN}Adapt config file for ROKS on IBM Cloud${NC}"
        #  ${SED} -i "s/roks_enabled: false/roks_enabled: true/" cluster/config.yaml
        #  ${SED} -i "s/<roks_url>/$CLUSTER_NAME/" cluster/config.yaml
        fi
        echo " ${GREEN}OK${NC}"
echo "${CYAN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${CYAN}***************************************************************************************************************************${NC}"
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "


echo "${GREEN}***************************************************************************************************************************{NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${GREEN}Current config file for installation${NC}"
echo " ${GREEN}Please Check if it looks OK${NC}"
echo " ${ORANGE}vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv${NC}"
echo "  "
        cat cluster/config.yaml
echo "  "
echo " ${ORANGE}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^${NC}"
echo " ${GREEN}Current config file for installation${NC}"
echo " ${GREEN}Please Check if it looks OK${NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}***************************************************************************************************************************${NC}"
echo "  "
echo "  "
echo "  "
echo "  "





# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# INSTALL
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "${ORANGE}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${ORANGE}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${RED}${whitequestion} Do you want to install MCM into Cluster '$CLUSTER_NAME' with the above configuration?${NC}"
echo ""
echo "${ORANGE}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${ORANGE}---------------------------------------------------------------------------------------------------------------------------${NC}"

        read -p "Install? [y,N]" DO_COMM
        if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then

          cd cluster 
          docker run -t --net=host -e LICENSE=accept -v $(pwd):/installer/cluster:z -v /var/run:/var/run:z -v /etc/docker:/etc/docker:z --security-opt label:disable $ENTITLED_REGISTRY/cp/icp-foundation/mcm-inception:$MCM_INCEPTION_VERSION install-with-openshift
        else
          echo "${RED}${cross} Installation Aborted${NC}"
          exit 2
        fi

echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${GREEN}${healthy} MCM Installation.... DONE${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${GREEN}${explosion} To remove:           docker run -t --net=host -e LICENSE=accept -v $(pwd):/installer/cluster:z -v /var/run:/var/run:z -v /etc/docker:/etc/docker:z --security-opt label:disable $ENTITLED_REGISTRY/cp/icp-foundation/mcm-inception:$MCM_INCEPTION_VERSION uninstall-with-openshift${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"


exit 2
