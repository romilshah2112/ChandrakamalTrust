import whisper
from fastapi import FastAPI, UploadFile, File
import shutil
import os

app = FastAPI()

model = whisper.load_model("medium")  # base is faster than small

@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    temp_filename = f"temp_{file.filename}"

    with open(temp_filename, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    result = model.transcribe(temp_filename)

    os.remove(temp_filename)

    return {"text": result["text"]}