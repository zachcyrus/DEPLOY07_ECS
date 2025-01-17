# Deploying a Jenkins Container through Fargate

## Steps to replicate

### Build a Jenkins image and push that image to AWS Elastic Container Registry (ECR)

1. Create a Dockerfile to build a [Jenkins image](https://github.com/zachcyrus/jenkins_docker/tree/main/jenkins_container).

  ```
  FROM jenkins/jenkins:2.303.1-jdk11
  USER root
  RUN apt-get update && apt-get install -y apt-transport-https \
         ca-certificates curl gnupg2 \
         software-properties-common
  RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
  RUN apt-key fingerprint 0EBFCD88
  RUN add-apt-repository \
         "deb [arch=amd64] https://download.docker.com/linux/debian \
         $(lsb_release -cs) stable"
  RUN apt-get update && apt-get install -y docker-ce-cli
  USER jenkins
  RUN jenkins-plugin-cli --plugins "blueocean:1.25.0 docker-workflow:1.26"
  ```

2. Log into your AWS account and navigate to AWS ECR and create a new public repository, name the repository after the image you plan to create. I named it jenkins-image. 

3. Once your public repository has been created open up your terminal/cli and navigate to the directory containing your Dockerfile. 
4. Go back to AWS ECR and click your repositories push commands in order to push your image to AWS. The first command will verify your AWS login credentials(make you have your AWS cli configured)
The second command will build your image locally based off the Dockerfile. 
The third command will tag your image with the link to your repository on ECR.
The last command will push your image to AWS.

#### Troubleshooting 
- If you're on an M1 mac you're going to have to use Docker's buildx command to build an image that is compatible with x86 architecture. Since AWS Fargate defaults to Intel architecture.
- 
  ```
  # Use this command instead of the second command listed on AWS ECR push commands for your repository.
  docker buildx build --platform linux/amd64 -t jenkins-image .
  ```

### Launch a Jenkins container through AWS ECS

1. Navigate to AWS ECS and choose Clusters to create a new Cluster, and choose networking only with the default VPC.
2. After your cluster is created go to the task section and create a new task definition.
3. While creating your task definition link to the ECR repo where your jenkins image is hosted, and make sure to map port 8080.
4. Once this new task is created navigate to your AWS cluster and run a new task with the task definition you just created.
5. Once this new task is running (might take a couple minutes) look through the logs of the container for the initial admin password needed to login to jenkins.

### Create an Ubuntu Agent
1. Create a t2 micro Ubuntu EC2 instance and ssh into that instance.
2. This instance will be used as our agent to build on.
3. For our use case we will install Docker using a convenience script.
  ```
 curl -fsSL https://get.docker.com -o get-docker.sh
 sudo sh get-docker.sh
 ```

### Create an image to build to Java application

1. Write a Dockerfile to build an image based on our Java application.
   ```
   FROM openjdk:11
   COPY ./demo-0.0.1-SNAPSHOT.jar app.jar
   CMD ["java","-jar","app.jar"]
   
   ```
2. Save this Dockerfile in the repository of your target application.

### Run a CI/CD Pipeline with Jenkinsfile 
1. Create a new pipeline job in Jenkins, which will read a Jenkinsfile from your Github repository of choice, and add necessary credentials.
2. Add a Jenkinsfile to your target repo with the following.
   ```
   pipeline {
    agent {
        label "Ubuntu"
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('DockerCredentials')
    }

    stages {
        stage ('Build') {
            steps {
                sh '''
                docker build -t zcyrus/spring-app .
                '''
            }
        }

        stage ('Login'){
            steps {
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
            }
        }

        stage ('Push') {

            steps{

                sh 'docker push zcyrus/spring-app:latest'

            }
            
        }
    }

    post {
        always {
            sh 'docker logout'
        }
    }
    
    ``` 

