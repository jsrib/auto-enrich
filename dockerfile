FROM ubuntu:24.04


RUN apt-get update && \
	apt-get -y upgrade && \
	apt-get install -y software-properties-common && \
	apt-get install -y python3 python3-pip graphviz unzip curl jq wget bc fonts-dejavu-core && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages -Iv \
	unipressed==1.2.0 \
	beautifulsoup4==4.12.2 \
	click==8.1.7 \
	requests==2.31.0 \
	anytree \
	pydot \
	reportlab \
	matplotlib \
	pandas \
	seaborn

COPY code.zip /opt
WORKDIR /opt
RUN unzip code.zip && rm code.zip
RUN chmod -R 777 *

ENTRYPOINT ["./run"]