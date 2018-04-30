FROM registry.centos.org/centos/centos:7

MAINTAINER Shubham <shubham@linux.com>

EXPOSE 8182

RUN yum -y install epel-release &&\
    yum -y install git zip unzip awscli &&\
    yum -y install java java-devel maven &&\
    yum clean all

# set JAVA_HOME
ENV JAVA_HOME /usr/lib/jvm/java-openjdk

RUN curl -O https://s3.amazonaws.com/gremlin-tarballs/titan-all.tgz &&\
    tar xzf titan-all.tgz &&\
    rm -Rf titan-all.tgz

# Prep, build and install DynamoDB storage backend driver with support for titan, and install Gremlin server
# TODO: does anybody understand what is going on here? Why is it so complicated and there are no comments?
RUN mkdir /repo &&\
    chmod 755 /repo &&\
    git clone https://github.com/awslabs/dynamodb-titan-storage-backend.git /opt/dynamodb/dynamodb-titan-storage-backend/ &&\
    cd /opt/dynamodb/dynamodb-titan-storage-backend/ &&\
    git checkout d1a59624dcef796b835e7ffb41f0a3f007008d63 -b "last-working" &&\
    curl https://gist.githubusercontent.com/pluradj/d56c1948f4665ee7fb1bc35daeba4f92/raw/be5f639a64c8d6ac196c59eb7e6d1a1903015b17/dynamo-titan11-tp323.patch | git apply -v --index &&\
    mvn -Dmaven.repo.local=/repo install &&\
    rm -Rf /opt/dynamodb/dynamodb-titan-storage-backend/server/dynamodb-titan100-storage-backend-1.0.0-hadoop1.zip &&\
    cd /opt/dynamodb/dynamodb-titan-storage-backend/ &&\
    curl -o /opt/titan-1.1.0-SNAPSHOT-hadoop2.zip https://s3.amazonaws.com/gremlin-tarballs/titan-1.1.0-SNAPSHOT-hadoop2.zip &&\
    sed -i 's#TITAN_VANILLA_SERVER_ZIP=.*#TITAN_VANILLA_SERVER_ZIP=/opt/titan-1.1.0-SNAPSHOT-hadoop2.zip#' src/test/resources/install-gremlin-server.sh &&\
    src/test/resources/install-gremlin-server.sh &&\
    mkdir -p /repo/repository/org/slf4j/slf4j-api/1.7.21/ &&\
    cd dynamodb-titan-storage-backend/server/dynamodb-titan100-storage-backend-1.0.0-hadoop1 &&\
    curl -o /repo/repository/org/slf4j/slf4j-api/1.7.21/slf4j-api-1.7.21.jar http://central.maven.org/maven2/org/slf4j/slf4j-api/1.7.21/slf4j-api-1.7.21.jar &&\
    bin/gremlin-server.sh -i org.apache.tinkerpop gremlin-python 3.2.3 &&\
    rm -Rf /repo /opt/titan-1.1.0-SNAPSHOT-hadoop2.zip

WORKDIR /opt/dynamodb/

ADD scripts/entrypoint.sh /bin/entrypoint.sh

RUN chmod +x /bin/entrypoint.sh &&\
    chgrp -R 0 /opt/dynamodb/ &&\
    chmod -R g+rw /opt/dynamodb/ &&\
    find /opt/dynamodb/ -type d -exec chmod g+x {} +

ADD scripts/entrypoint-local.sh /bin/entrypoint-local.sh
RUN chmod +x /bin/entrypoint-local.sh

COPY scripts/post-hook.sh /bin/

ENTRYPOINT ["/bin/entrypoint.sh"]

