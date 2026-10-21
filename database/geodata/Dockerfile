# Build
FROM eclipse-temurin:25-jdk AS build
WORKDIR /src
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle gradle
RUN ./gradlew --no-daemon -q dependencies > /dev/null
COPY src src
RUN ./gradlew --no-daemon -q bootJar -x test

# Run: the Java imports and osm2pgsql for the OpenStreetMap extract
FROM eclipse-temurin:25-jre
RUN apt-get update \
 && apt-get install -y --no-install-recommends osm2pgsql curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10002 geodata
WORKDIR /app
COPY --from=build /src/build/libs/geodata.jar geodata.jar
COPY osm osm
COPY refresh.sh refresh.sh
RUN chmod +x refresh.sh osm/load.sh
USER geodata
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"
ENTRYPOINT ["/app/refresh.sh"]
