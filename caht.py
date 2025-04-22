import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from openai import OpenAI
from typing import List
import uvicorn

# Claves


# Inicializar FastAPI
app = FastAPI()

# CORS por si lo necesitas
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Historial simple (en memoria, por sesión global)
conversation_history: List[dict] = [
    {"role": "system", "content": "You are a helpful assistant."}
]

class QueryRequest(BaseModel):
    pregunta: str

class QueryResponse(BaseModel):
    respuesta: str
    historial: List[dict]
    contexto: List[str]

@app.get("/")
async def root():
    return {"message": "Hola, RAG Assistant activo"}

@app.post("/query", response_model=QueryResponse)
async def query_openai(request: QueryRequest):
    try:
        # Embeddings + Vector DB
        embeddings = OpenAIEmbeddings(
            model="text-embedding-ada-002",
            openai_api_key=OPENAI_API_KEY
        )
        vector_store = Chroma(persist_directory="chroma_db", embedding_function=embeddings)

        # Recuperar contexto desde Chroma
        docs = vector_store.similarity_search(request.pregunta)
        context = [doc.page_content for doc in docs]

        # Agregar el contexto como parte del mensaje system
        context_message = {
            "role": "system",
            "content": f"Basado en los siguientes documentos legales, responde de forma precisa y contextual:\n\n{chr(10).join(context)}"
        }

        # Construir historial para la petición, incluyendo contexto explícito
        messages = conversation_history.copy()
        messages.insert(1, context_message)  # Insertar después del primer mensaje system

        # Añadir pregunta del usuario
        messages.append({
            "role": "user",
            "content": f"Question: {request.pregunta}"
        })

        # Llamada a OpenAI con historial + contexto
        client = OpenAI(api_key=OPENAI_API_KEY)
        completion = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=messages
        )

        # Obtener respuesta
        respuesta = completion.choices[0].message.content

        # Actualizar historial global
        conversation_history.append({
            "role": "user",
            "content": f"Question: {request.pregunta}"
        })
        conversation_history.append({
            "role": "assistant",
            "content": respuesta
        })

        return QueryResponse(
            respuesta=respuesta,
            historial=conversation_history,
            contexto=context
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
