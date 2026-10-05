FROM maven:3.9.11-eclipse-temurin-21
WORKDIR /tests
COPY pom.xml ./
RUN mvn --batch-mode --no-transfer-progress dependency:go-offline
COPY src ./src
CMD ["mvn", "--batch-mode", "--no-transfer-progress", "verify"]
