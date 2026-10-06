FROM maven:3.9.11-eclipse-temurin-21
RUN groupadd --system tests \
    && useradd --system --gid tests --create-home tests \
    && mkdir -p /tests \
    && chown tests:tests /tests
WORKDIR /tests
COPY --chown=tests:tests pom.xml ./
ENV MAVEN_CONFIG=/home/tests/.m2
USER tests
RUN mvn --batch-mode --no-transfer-progress dependency:go-offline
COPY --chown=tests:tests src ./src
CMD ["mvn", "--batch-mode", "--no-transfer-progress", "verify"]
