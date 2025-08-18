pipeline {
  agent any

  environment {
    AWS_REGION       = "ap-south-1"
    AWS_ACCOUNT_ID   = "141282679348"
    ECR_REPO         = "flask-app"
    IMAGE_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    IMAGE            = "${IMAGE_REGISTRY}/${ECR_REPO}"
    K8S_NAMESPACE    = "flaskapp"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Lint') {
      steps {
        sh '''
          # Create isolated virtual environment
          python3 -m venv venv
          . venv/bin/activate

          pip install --upgrade pip
          pip install flake8

          flake8 --version
          flake8 app.py
        '''
      }
    }

    stage('Build Image') {
      steps {
        script {
          IMAGE_TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          env.IMAGE_TAG = IMAGE_TAG
          sh "docker build -t ${IMAGE}:${IMAGE_TAG} -t ${IMAGE}:latest ."
        }
      }
    }

    stage('Login & Push to ECR') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-cred', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

            # ECR login
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${IMAGE_REGISTRY}

            # create repo if not exists
            aws ecr describe-repositories --repository-names ${ECR_REPO} --region ${AWS_REGION} >/dev/null 2>&1 || \
              aws ecr create-repository --repository-name ${ECR_REPO} --region ${AWS_REGION} || true

            docker push ${IMAGE}:${IMAGE_TAG}
            docker push ${IMAGE}:latest
          '''
        }
      }
    }

    stage('Basic Container Test') {
      steps {
        sh '''
          TEST_PORT=5002
          docker run -d --name jenkins_test_flask -p ${TEST_PORT}:5000 ${IMAGE}:${IMAGE_TAG}
          sleep 4
          curl -f http://localhost:${TEST_PORT}/health
          docker rm -f jenkins_test_flask
        '''
      }
    }

    stage('Deploy to EKS') {
      steps {
        withCredentials([file(credentialsId: 'eks-kubeconfig', variable: 'KUBECONFIG_FILE')]) {
          sh '''
            export KUBECONFIG=${KUBECONFIG_FILE}
            kubectl -n ${K8S_NAMESPACE} set image deployment/flask-app flask-app=${IMAGE}:${IMAGE_TAG} --record || \
              sed "s|IMAGE_PLACEHOLDER|${IMAGE}:${IMAGE_TAG}|g" k8s/deployment.yaml | kubectl -n ${K8S_NAMESPACE} apply -f -
            kubectl -n ${K8S_NAMESPACE} rollout status deployment/flask-app --timeout=120s
          '''
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline completed successfully. Image: ${IMAGE}:${IMAGE_TAG}"
    }
    failure {
      echo "Pipeline failed. Check console output for errors."
    }
  }
}

