# Latest benchmark verdict (E2B sweep, 4GB card)

- Winner/default: plain Gemma 4 E2B Q4_0 (2.71GB) - full read->edit->bash loop (fix verified
  on disk $113,537.50) AND fastest decode of everything tested on the stock build (44-45 t/s).
  Supersedes Qwen3-4B as top pick. models.json default -> gemma4-e2b-Q4_0.gguf.
- Larger quant decoded FASTER than smaller on same build: Q4_0 = 44-45 t/s vs Q3_K_M = 36 t/s
  (both stock b10488). Do NOT assume smaller quant is faster - bench the higher quant.
- Cactus Hybrid E2B: live confidence probe but needs patched b10076 build, ~8 t/s. Revisit
  only when upstream llama.cpp adds hybrid arch natively.
- 4GB decode ranking: E2B Q4_0 (44-45) > Q3_K_M (36) > Gemma3 (32) > Qwen3-4B (31.7) >
  Qwen3.8 (25.7) > Qwen3.5 (24.9).
