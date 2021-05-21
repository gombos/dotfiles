FROM 0gombi0/homelab:base

COPY bin/* packages/* /tmp/
WORKDIR /tmp/
RUN infra-build-srv.sh

CMD ["/bin/bash"]
