pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    environment {
        COMPOSE_PROJECT = 'king-phisher'
        REPO_DIR        = 'king-phisher-src'
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
                // required: docker-compose.yml declares kp-net as external,
                // so compose up fails outright if it doesn't already exist
                sh 'docker network create kp-net || true'
            }
        }

        stage('Build images') {
            steps {
                dir(env.REPO_DIR) {
                    // db is `image: postgres:13` — pulled, not built, so it's
                    // intentionally excluded here; `compose up` pulls it below
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
                            RESPONSE=$(curl -s -D - -o /dev/null --max-time 3 http://localhost:443/ 2>/dev/null)
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

                        # 404 at / is CORRECT — no campaign is configured, so a 404
                        # proves the request reached the real King Phisher handler
                        # rather than some other service on the port.
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
        }
        failure {
            echo 'King Phisher deploy/smoke-test failed — check the archived server log.'
        }
    }
}
