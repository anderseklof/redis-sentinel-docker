FROM ubuntu:22.04

COPY ./script/redis-ubuntu.sh .

RUN chmod +x ./redis-ubuntu.sh
RUN ./redis-ubuntu.sh
