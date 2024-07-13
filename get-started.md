

az group create --name myResourceGroup --location eastus

Generate service principle with json output:

MSYS2_ARG_CONV_EXCL='/s' az ad sp create-for-rbac --name test-processing --role contributor --scopes /subscriptions/2ed06bf5-fd72-4e3a-b571-d13d54exxxx/resourceGroups/myResourceGroup --sdk-auth

Set secrets:

![image](https://github.com/user-attachments/assets/71e6e640-2450-49cc-9e02-556ed464fa38)


Clean resources:

az group delete  --resource-group  myResourceGroup --yes --no-wait
