FROM 0gombi0/homelab:base

COPY bin/*.sh packages/*.l /
RUN /infra-build-srv.sh

CMD ["/bin/bash"]
