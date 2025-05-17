FROM tomcat:10-jdk11-temurin

LABEL maintainer="Sarafrika <info@sarafrika.com>"

# Environment variables
ENV JAVA_OPTS="-server -Xms1G -Xmx4G -XX:+UseG1GC -XX:+UseCompressedOops -XX:+DisableExplicitGC"
ENV CATALINA_OPTS="-Dsakai.home=/usr/local/sakai"
ENV MAVEN_OPTS="-Xms512m -Xmx1024m"

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    wget \
    unzip \
    maven \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /usr/local/sakai/properties

# Download the specific Sakai release
WORKDIR /tmp
ARG SAKAI_VERSION=23.0
RUN git clone -b ${SAKAI_VERSION} --depth 1 https://github.com/sakaiproject/sakai.git

# Build Sakai using Maven with JDK 11
WORKDIR /tmp/sakai
RUN mvn clean install -Dmaven.test.skip=true -Djava.net.preferIPv4Stack=true

# Copy the built Sakai to Tomcat webapps
RUN cp -R webapps/* $CATALINA_HOME/webapps/

# Download MariaDB JDBC connector
WORKDIR /tmp
RUN wget https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.3.2/mariadb-java-client-3.3.2.jar \
    && mv mariadb-java-client-3.3.2.jar $CATALINA_HOME/lib/

# Copy configuration files from repository
COPY config/sakai.properties /usr/local/sakai/properties/
COPY config/local.properties /usr/local/sakai/properties/
COPY tomcat/server.xml $CATALINA_HOME/conf/

# Set proper permissions
RUN chmod -R 755 $CATALINA_HOME/webapps/
RUN mkdir -p $CATALINA_HOME/sakai && \
    chmod -R 777 $CATALINA_HOME/sakai

# Expose port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]