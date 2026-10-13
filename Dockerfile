# java jdk 17
FROM eclipse-temurin:17-jre

# Set port number
EXPOSE 2222

# Set the working directory in the container
WORKDIR /app

# Copy the packaged JAR file into the container
COPY target/devOpsDemo-0.0.1-SNAPSHOT.jar app.jar

# Specify the command to run on container startup
CMD ["java", "-jar", "app.jar"]
