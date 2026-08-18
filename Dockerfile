FROM ubuntu:latest
LABEL authors="nekra"

ENTRYPOINT ["top", "-b"]