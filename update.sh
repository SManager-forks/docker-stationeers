#!/usr/bin/env bash

set -e
trap "exit" SIGINT

if [ "$USER" == "root" ]
then
	echo "Must not be executed as user \"root\"!"
	exit -1
fi

if ! [ -x "$(command -v jq)" ]
then
	echo "JSON Parser \"jq\" is required but not installed!"
	exit -2
fi

if ! [ -x "$(command -v curl)" ]
then
	echo "\"curl\" is required but not installed!"
	exit -3
fi

WORK_DIR="${0%/*}"
cd "$WORK_DIR"

CURRENT_VERSION=$(git describe --tags --abbrev=0)
NEXT_VERSION="$CURRENT_VERSION"

# Base Image
IMAGE_NAME="hetsh/steamcmd"
CURRENT_STEAMCMD_VERSION=$(cat Dockerfile | grep "FROM $IMAGE_NAME:")
CURRENT_STEAMCMD_VERSION="${CURRENT_STEAMCMD_VERSION#*:}"
STEAMCMD_VERSION=$(curl -L -s "https://registry.hub.docker.com/v2/repositories/$IMAGE_NAME/tags" | jq '."results"[]["name"]' | grep -m 1 -P -o "(\d+\.)+\d+-\d+" )
if [ "$CURRENT_STEAMCMD_VERSION" != "$STEAMCMD_VERSION" ]
then
	echo "SteamCMD $STEAMCMD_VERSION available!"

	RELEASE="${CURRENT_VERSION#*-}"
	NEXT_VERSION="${CURRENT_VERSION%-*}-$((RELEASE+1))"
fi

# Stationeers Manifest
CURRENT_MANIFEST_ID=$(cat Dockerfile | grep "ARG MANIFEST_ID=")
CURRENT_MANIFEST_ID=${CURRENT_MANIFEST_ID#*=}
MANIFEST_ID=$(curl -L -s 'https://steamdb.info/depot/600762/' | grep -P -o "<td>\d+" | tr -d '<td>' | tail -n 1)
if [ "$CURRENT_MANIFEST_ID" != "$MANIFEST_ID" ]
then
	echo "Manifest ID $MANIFEST_ID available!"

	RELEASE="${CURRENT_VERSION#*-}"
	NEXT_VERSION="${CURRENT_VERSION%-*}-$((RELEASE+1))"
fi

# Stationeers Version
CURRENT_STATIONEERS_VERSION="${CURRENT_VERSION%-*}"
STATIONEERS_VERSION=$(curl -L -s "https://store.steampowered.com/news/?appids=544550&appgroupname=Stationeers" | grep -P -o "(\d+\.){3}\d+" | head -n 1)
if [ "$CURRENT_STATIONEERS_VERSION" != "$STATIONEERS_VERSION" ]
then
	echo "Stationeers Server $STATIONEERS_VERSION available"

	NEXT_VERSION="$STATIONEERS_VERSION-1"
fi

if [ "$CURRENT_VERSION" == "$NEXT_VERSION" ]
then
	echo "No updates available."
else
	if [ "$1" == "--noconfirm" ]
	then
		SAVE="y"
	else
		read -p "Save changes? [y/n]" -n 1 -r SAVE && echo
	fi
	
	if [[ $SAVE =~ ^[Yy]$ ]]
	then
		if [ "$CURRENT_STEAMCMD_VERSION" != "$STEAMCMD_VERSION" ]
		then
			sed -i "s|FROM $IMAGE_NAME:.*|FROM $IMAGE_NAME:$STEAMCMD_VERSION|" Dockerfile
		fi

		if [ "$CURRENT_MANIFEST_ID" != "$MANIFEST_ID" ]
		then
			sed -i "s|ARG RS_MANIFEST_ID=\".*\"|ARG RS_MANIFEST_ID=\"$MANIFEST_ID\"|" Dockerfile
		fi

		if [ "$1" == "--noconfirm" ]
		then
			COMMIT="y"
		else
			read -p "Commit changes? [y/n]" -n 1 -r COMMIT && echo
		fi

		if [[ $COMMIT =~ ^[Yy]$ ]]
		then
			git add Dockerfile
			git commit -m "Version bump to $NEXT_VERSION"
			git push
			git tag "$NEXT_VERSION"
			git push origin "$NEXT_VERSION"
		fi
	fi
fi
