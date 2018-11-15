FROM centos/systemd

# Setup container to utilize systemd
ENV container docker
STOPSIGNAL SIGRTMIN+3
RUN systemctl mask sys-fs-fuse-connections.mount

# Install packages
RUN yum -y install epel-release
RUN yum -y install python2 python2-pip python-devel libffi-devel \
    openssl-devel libxml2-devel libxslt-devel zlib-devel swig \
    python-virtualenv python-setuptools bridge-utils libvirt-python \
    tcpdump guacd libpqxx-devel sudo gcc python2-devel python34-devel \
    libjpeg-devel libguac-client-vnc libguac-client-rdp \
    libguac-client-ssh yara python2-yara ssdeep ssdeep-devel \
    openssh-clients unzip
RUN pip install setuptools m2crypto==0.24.0 psycopg2 \
    mitmproxy==0.18.2 weasyprint==0.40 distorm3 pydeep pycrypto pytz \
    ujson

# Install and update Cuckoo
RUN pip install -U cuckoo
WORKDIR /root
RUN cuckoo -d
WORKDIR /root/.cuckoo
RUN cuckoo --cwd /root/.cuckoo community

# Configure Cuckoo to utilize localhost as hypervisor
RUN sed -i -e 's/qemu:\/\/\/system/qemu+ssh:\/\/127.0.0.1\/system/' \
    /usr/lib/python2.7/site-packages/cuckoo/machinery/kvm.py && sed \
    -i -e 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/' \
    /etc/ssh/ssh_config

# Install volatility
RUN curl -o vol.zip -L \
    "https://github.com/volatilityfoundation/volatility/archive/master.zip" && \
    unzip vol.zip && cd volatility-master && python setup.py install && \
    cd ../ && rm -rf volatility-master && rm -f vol.zip

# Download and install yara rules
WORKDIR /root/.cuckoo/yara
COPY yara-rules.py /root/.cuckoo/yara
RUN yum -y install python36 python36-setuptools && easy_install-3.6 pip && pip3 install requests && python36 yara-rules.py && rm -f yara-rules.py && rm -f binaries/MAL*
WORKDIR /root/.cuckoo

# Install services
COPY cuckoo.service /usr/lib/systemd/system/cuckoo.service
COPY cuckoo-web.service /usr/lib/systemd/system/cuckoo-web.service
COPY cuckoo-proc1.service /usr/lib/systemd/system/cuckoo-proc1.service
COPY cuckoo-proc2.service /usr/lib/systemd/system/cuckoo-proc2.service
COPY cuckoo-proc3.service /usr/lib/systemd/system/cuckoo-proc3.service
COPY cuckoo-proc4.service /usr/lib/systemd/system/cuckoo-proc4.service
COPY cuckoo-rooter.service /usr/lib/systemd/system/cuckoo-rooter.service
RUN systemctl enable cuckoo cuckoo-web guacd cuckoo-proc1 cuckoo-proc2 \
    cuckoo-proc3 cuckoo-proc4

# Setup house keeping scripts
COPY rc.local /etc/rc.local
RUN chmod +x /etc/rc.local
COPY kube-start.sh /usr/bin/kube-start
RUN chmod +x /usr/bin/kube-start
COPY deploy.yml /tmp/deploy.yml

CMD ["/usr/sbin/init"]

