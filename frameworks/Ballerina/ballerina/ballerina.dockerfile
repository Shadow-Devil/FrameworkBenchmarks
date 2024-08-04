FROM ballerina/ballerina:2201.9.2 as ballerina

WORKDIR /ballerina
COPY Ballerina.toml Ballerina.toml
COPY Dependencies.toml Dependencies.toml
COPY main.bal main.bal

RUN bal build

FROM amazoncorretto:17.0.11-al2023-headless
WORKDIR /ktor
COPY --from=ballerina /ballerina/target/bin/ballerina.jar app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
