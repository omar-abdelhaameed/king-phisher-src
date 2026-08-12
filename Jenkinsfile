pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    triggers {
        githubPush()
    }

    environment {
        COMPOSE_PROJECT   = 'king-phisher'
        REPO_DIR          = 'king-phisher-src'
        SLACK_WEBHOOK_URL = credentials('slack-webhook-url')
    }

    stages {
        stage('Checkout') {
            steps {
                dir(env.REPO_DIR) {
                    git branch: 'master', url: 'https://github.com/omar-abdelhaameed/king-phisher-src.git'
                }
            }
        }

        stage('Ensure network') {
            steps {
                sh 'docker network create kp-net || true'
                sh 'docker network create devsecops-net || true'
            }
        }

        stage('Build images') {
            steps {
                dir(env.REPO_DIR) {
                    sh "docker compose -f docker-compose.yml -p ${COMPOSE_PROJECT} build king-phisher king-phisher-client"
                }
            }
        }

        stage('Deploy & smoke test') {
            steps {
                dir(env.REPO_DIR) {
                    sh "docker compose -f docker-compose.yml -p ${COMPOSE_PROJECT} up -d db king-phisher"

                    sh '''
                        ATTEMPTS=0
                        MAX_ATTEMPTS=20
                        SUCCESS=0
                        while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
                            RESPONSE=$(docker exec king-phisher-king-phisher-1 curl -s -D - -o /dev/null --max-time 3 http://localhost:80/ 2>/dev/null || true)
                            if [ -n "$RESPONSE" ]; then
                                SUCCESS=1
                                break
                            fi
                            ATTEMPTS=$((ATTEMPTS+1))
                            sleep 3
                        done

                        if [ "$SUCCESS" -ne 1 ]; then
                            echo "Server never became reachable after $((MAX_ATTEMPTS*3)) seconds"
                            exit 1
                        fi

                        STATUS=$(echo "$RESPONSE" | head -1 | awk '{print $2}')
                        echo "Server responded with HTTP $STATUS"
                        echo "$RESPONSE" | grep -i "^Server:" || true

                        if [ "$STATUS" != "404" ]; then
                            echo "Unexpected status — expected 404 from the King Phisher handler"
                            exit 1
                        fi

                        if ! echo "$RESPONSE" | grep -qi "AdvancedHTTPServer"; then
                            echo "404 received, but not from AdvancedHTTPServer — wrong service on this port?"
                            exit 1
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            dir(env.REPO_DIR) {
                sh "docker compose -f docker-compose.yml -p ${COMPOSE_PROJECT} logs king-phisher > king-phisher-server.log || true"
                sh "docker compose -f docker-compose.yml -p ${COMPOSE_PROJECT} down || true"
            }
            archiveArtifacts artifacts: "${REPO_DIR}/king-phisher-server.log", allowEmptyArchive: true

            // unified findings/history record, queryable across both pipelines
            sh """
                docker run --rm --network devsecops-net postgres:13 \
                psql "postgresql://devsecops:devsecops-findings-pw@devsecops-findings-db/devsecops" \
                -c "INSERT INTO pipeline_runs (pipeline_name, build_number, git_commit, status) VALUES ('king-phisher-deploy', ${BUILD_NUMBER}, '${env.GIT_COMMIT}', '${currentBuild.currentResult}');" || true
            """
        }
        success {
            sh '''
                curl -s -X POST -H 'Content-type: application/json' \
                    --data '{"text":"✅ king-phisher-deploy build #'"${BUILD_NUMBER}"' succeeded"}' \
                    "$SLACK_WEBHOOK_URL"
            '''
        }
        failure {
            sh '''
                curl -s -X POST -H 'Content-type: application/json' \
                    --data '{"text":"❌ king-phisher-deploy build #'"${BUILD_NUMBER}"' FAILED — check console output"}' \
                    "$SLACK_WEBHOOK_URL"
            '''
            echo 'King Phisher deploy/smoke-test failed — check the archived server log.'
        }
    }
}
