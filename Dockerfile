FROM openjdk:11
COPY ./demo-0.0.1-SNAPSHOT.jar app.jar
CMD ["java","-jar","app.jar"]