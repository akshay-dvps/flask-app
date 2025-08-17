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
          # install flake8 into user environment (safe)
          python3 -m pip install --user flake8 || true
          export PATH=$HOME/.local/bin:$PATH
          flake8 --version || true
          flake8 app.py || true
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
            aws --version || true

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
          # run the newly built image on the agent and test /health (use ephemeral port)
          TEST_PORT=5002
          docker run -d --name jenkins_test_flask -p ${TEST_PORT}:5000 ${IMAGE}:${IMAGE_TAG} || true
          sleep 4
          curl -f http://localhost:${TEST_PORT}/health
          docker rm -f jenkins_test_flask || true
        '''
      }
    }

    stage('Deploy to EKS') {
      steps {
        // if you prefer a manual approval, replace this block with the Input step shown below
        withCredentials([file(credentialsId: 'eks-kubeconfig', variable: 'KUBECONFIG_FILE')]) {
          sh '''
            export KUBECONFIG=${KUBECONFIG_FILE}
            # Update deployment image using kubectl set image (preferred):
            kubectl -n ${K8S_NAMESPACE} set image deployment/flask-app flask-app=${IMAGE}:${IMAGE_TAG} --record || \
              # fallback to apply the manifest if set image fails
              sed "s|IMAGE_PLACEHOLDER|${IMAGE}:${IMAGE_TAG}|g" k8s/deployment.yaml | kubectl -n ${K8S_NAMESPACE} apply -f -
            kubectl -n ${K8S_NAMESPACE} rollout status deployment/flask-app --timeout=120s
          '''
        }
      }
    }
  } // stages

  post {
    success {
      echo "Pipeline completed successfully. Image: ${IMAGE}:${IMAGE_TAG}"
    }
    failure {
      echo "Pipeline failed. Check console output for errors."
    }
  }
}
