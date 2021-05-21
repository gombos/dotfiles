FROM 0gombi0/homelab:base

COPY bin/* packages/* /tmp/
RUN /tmp/infra-build-srv.sh

CMD ["/bin/bash"]
