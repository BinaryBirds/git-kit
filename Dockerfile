FROM swift
WORKDIR /app
COPY . ./
CMD swift package clean
CMD swift test --parallel
