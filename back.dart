from fastapi import FastAPI
from pydantic import BaseModel
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma
from openai import OpenAI
import os
from azure.storage.blob import BlobServiceClient

# Configuración de OpenRouter
OPENROUTER_API_KEY = "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"
client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=OPENROUTER_API_KEY,
)

# Configuración de Azure Blob Storage
BLOB_CONNECTION_STRING = "el net va aqui"
CONTAINER_NAME = "topicos"
BLOB_NAME = "chroma.sqlite3"

# Descarga la base de datos desde Azure Blob Storage si no existe localmente
if not os.path.exists("chroma_db/chroma.sqlite3"):
    os.makedirs("chroma_db", exist_ok=True)
    blob_service_client = BlobServiceClient.from_connection_string(BLOB_CONNECTION_STRING)
    blob_client = blob_service_client.get_blob_client(container=CONTAINER_NAME, blob=BLOB_NAME)
    with open("chroma_db/chroma.sqlite3", "wb") as db_file:
        db_file.write(blob_client.download_blob().readall())

# Inicializar FastAPI
app = FastAPI()

# Modelo para la solicitud
class QueryRequest(BaseModel):
    pregunta: str

@app.post("/query")
async def query_openrouter(request: QueryRequest):
    try:
        # Cargar la base de datos Chroma
        embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
        vector_store = Chroma(persist_directory="chroma_db", embedding_function=embeddings)

        # Buscar fragmentos similares en la base de datos
        docs = vector_store.similarity_search(request.pregunta)

        # Preparar el contexto para OpenRouter
        context = "\n".join([doc.page_content for doc in docs])
        messages = [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": f"Context: {context}\n\nQuestion: {request.pregunta}"},
        ]

        # Llamar a la API de OpenRouter
        completion = client.chat.completions.create(
            extra_headers={
                "HTTP-Referer": "www.example.com",
                "X-Title": "oso",
            },
            model="deepseek/deepseek-r1:free",
            messages=messages,
        )

        # Extraer y devolver la respuesta
        response = completion.choices[0].message.content
        return {"respuesta": response}

    except Exception as e:
        return {"error": str(e)}
