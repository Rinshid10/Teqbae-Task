# Builds the mock API into a small container for hosting (e.g. Render).
# The server reads the PORT environment variable the host provides.
FROM dart:stable AS build
WORKDIR /app

COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Minimal runtime image: only the compiled server and the Dart runtime libs.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

EXPOSE 8080
CMD ["/app/bin/server"]
