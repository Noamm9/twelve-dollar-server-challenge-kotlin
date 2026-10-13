package dev.noamm9.velox.plugins

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.auth0.jwt.exceptions.JWTVerificationException
import dev.noamm9.velox.utils.JWT_SECRET
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.jwt.jwt
import io.ktor.server.response.respond

fun Application.configureAuthentication() {
    install(Authentication) {
        val verifier = JWT.require(Algorithm.HMAC256(JWT_SECRET)).build()

        jwt {
            verifier(verifier)

            validate { credential ->
                val payload = credential.payload
                val subject = payload.subject ?: return@validate null

                subject.toLongOrNull()?.takeIf { it > 0 } ?: return@validate null
                payload.getClaim("username").asString() ?: return@validate null

                JWTPrincipal(payload)
            }

            challenge { _, _ ->
                val authorization = call.request.headers[HttpHeaders.Authorization]

                if (authorization == null || ! authorization.startsWith("Bearer ")) {
                    return@challenge call.respond(
                        status = HttpStatusCode.Unauthorized, message = mapOf("error" to "missing bearer token")
                    )
                }

                val message = try {
                    val decoded = verifier.verify(authorization.removePrefix("Bearer "))

                    val subject = decoded.subject
                    val username = decoded.getClaim("username").asString()

                    when {
                        subject == null || subject.toLongOrNull()?.takeIf { it > 0 } == null || username == null -> "invalid token payload"
                        else -> "invalid or expired token"
                    }
                }
                catch (_: JWTVerificationException) {
                    "invalid or expired token"
                }
                catch (_: IllegalArgumentException) {
                    "invalid or expired token"
                }

                call.respond(status = HttpStatusCode.Unauthorized, message = mapOf("error" to message))
            }
        }
    }
}