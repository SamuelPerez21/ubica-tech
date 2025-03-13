PROPS_FILE='./src/main/resources/application.properties'
MAVEN_WAR_PLUGIN='<plugin><groupId>org.apache.maven.plugins<\/groupId><artifactId>maven-war-plugin<\/artifactId><configuration><failOnMissingWebXml>false<\/failOnMissingWebXml><\/configuration><\/plugin>'
VERSIONED_WAR_PLUGIN='<plugin><groupId>org.apache.maven.plugins<\/groupId><artifactId>maven-war-plugin<\/artifactId><version>3.4.0<\/version><configuration><failOnMissingWebXml>false<\/failOnMissingWebXml><\/configuration><\/plugin>'
SPRING_TEST_DEPENDENCY='<dependency><groupId>org.springframework<\/groupId><artifactId>spring-test<\/artifactId><version>4.3.13.RELEASE<\/version><scope>test<\/scope><\/dependency>'
MILESTONE_REPO='<repository><id>spring-milestones-fb<\/id><name>FB Milestones Repo<\/name><url>https:\/\/repo.spring.io\/milestone\/<\/url><\/repository>'

# Set the database URLs on application.properties
sed -e "s|jdbc:postgresql://localhost:5432/ss_demo_1|$1|g" -i $PROPS_FILE

# Remove whitespaces and newlines for easier parsing
sed -e ':a;N;$!ba;s/\n//g' -i ./pom.xml
sed -e 's/[[:space:]][[:space:]]\+//g' -i ./pom.xml
# Fix the javax servlet issue
sed -e 's/servlet-api/javax.servlet-api/g' -i ./pom.xml
# Fix the hibernate relocation issue
sed -e 's/org\.hibernate/org\.hibernate\.validator/g' -i ./pom.xml
# Re allocate the hibernate-core dependency
sed '0,/org\.hibernate\.validator/s//org\.hibernate/' -i ./pom.xml
# Remove the duplicate maven-war-plugin
sed "0,/$MAVEN_WAR_PLUGIN/s///" -i ./pom.xml
# Fix the maven-war-plugin issue
sed -e "s/$MAVEN_WAR_PLUGIN/$VERSIONED_WAR_PLUGIN/g" -i ./pom.xml
# Remove the duplicate spring-test dependency
sed -e "s/$SPRING_TEST_DEPENDENCY//g" -i ./pom.xml
# Fix http to https for secured repos
sed -e "s/http:/https:/g" -i ./pom.xml
# Fix the Facebook Social issue
sed -e "s/<\/repositories>/$MILESTONE_REPO<\/repositories>/g" -i ./pom.xml
