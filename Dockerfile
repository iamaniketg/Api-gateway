# Step 1: Build
FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app
COPY . .
RUN mvn -q -DskipTests clean package

# Step 2: Run
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
ENV JAVA_OPTS=""
ENV EUREKA_SERVER_URL=http://eureka-server:8761/eureka/
EXPOSE 8181
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]





