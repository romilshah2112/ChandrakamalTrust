FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY backend/src/Api/OptimaHealthcare.Api.csproj backend/src/Api/
COPY backend/src/Application/OptimaHealthcare.Application.csproj backend/src/Application/
COPY backend/src/Infrastructure/OptimaHealthcare.Infrastructure.csproj backend/src/Infrastructure/
COPY backend/src/Contracts/OptimaHealthcare.Contracts.csproj backend/src/Contracts/
COPY backend/src/Domain/OptimaHealthcare.Domain.csproj backend/src/Domain/

RUN dotnet restore backend/src/Api/OptimaHealthcare.Api.csproj

COPY backend/ backend/

RUN dotnet publish backend/src/Api/OptimaHealthcare.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

ENV ASPNETCORE_ENVIRONMENT=Production
ENV DOTNET_RUNNING_IN_CONTAINER=true

COPY --from=build /app/publish .

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "ASPNETCORE_URLS=http://+:${PORT:-8080} dotnet OptimaHealthcare.Api.dll"]
