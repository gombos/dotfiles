FROM 0gombi0/homelab:base

ENV SCRIPTS="/tmp"
COPY bin/* packages/* /tmp/
WORKDIR /tmp/
RUN ./infra-build-srv.sh

CMD ["/bin/bash"]
