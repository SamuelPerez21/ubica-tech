FROM node:12-alpine AS frontend-build
RUN apk add --no-cache git
RUN git clone --depth 1 --single-branch \
    --branch master \
    https://github.com/nromanen/Ch-058.git
WORKDIR /Ch-058/front-end
COPY ./docker/frontend-config ./
RUN npm install -D
RUN npm run build
RUN cp -r dist/** /Ch-058/src/main/webapp/

FROM maven:3-openjdk-8-slim AS backend-build
COPY --from=frontend-build /Ch-058/src /src
COPY --from=frontend-build /Ch-058/pom.xml /pom.xml
ARG DATABASE_URL
COPY ./docker/backend-config/config-fixes.sh ./
RUN chmod +x config-fixes.sh && ./config-fixes.sh $DATABASE_URL
RUN mvn clean install -DskipTests
RUN mvn liquibase:update -Dliquibase.promptOnNonLocalDatabase=false

FROM tomcat:9-jre8-alpine AS run
COPY --from=backend-build /target/*.war /usr/local/tomcat/webapps/
ENV HOST=0.0.0.0
ENV PORT=8080
EXPOSE 8080
CMD ["catalina.sh", "run"]
