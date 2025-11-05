import { useState, useEffect, useRef } from 'react'
import './ChatInterface.css'

// ===== CONFIGURACIÓN DE URLs =====
// Obtener URLs de WebSocket desde variables de entorno
// En desarrollo usa .env.development, en producción usa .env.production
const WS_TEXT_URL = import.meta.env.VITE_WS_TEXT_URL || 'ws://localhost:8000/ws/chat'
const WS_VOICE_URL = import.meta.env.VITE_WS_VOICE_URL || 'ws://localhost:8001/ws/voice'

// Log de configuración (solo en desarrollo)
if (import.meta.env.DEV) {
  console.log('🔧 Configuración WebSocket:')
  console.log('  - Texto:', WS_TEXT_URL)
  console.log('  - Voz:', WS_VOICE_URL)
}

function ChatInterface() {
  const [messages, setMessages] = useState([])
  const [inputText, setInputText] = useState('')
  const [isRecording, setIsRecording] = useState(false)
  const [isConnected, setIsConnected] = useState(false)
  const [isProcessing, setIsProcessing] = useState(false)
  const [connectionStatus, setConnectionStatus] = useState('Conectando...')
  const [threadId, setThreadId] = useState(null)
  const [sessionInitialized, setSessionInitialized] = useState(false)

  // Estados para modo voz
  const [isVoiceMode, setIsVoiceMode] = useState(false)
  const [voiceConnectionStatus, setVoiceConnectionStatus] = useState('Desconectado')
  const [isVoiceProcessing, setIsVoiceProcessing] = useState(false)

  const ws = useRef(null)
  const voiceWs = useRef(null)
  const messagesEndRef = useRef(null)
  const userId = useRef(`user_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`)
  const mediaRecorder = useRef(null)
  const audioContext = useRef(null)
  const audioStream = useRef(null)
  const playbackContext = useRef(null)
  const nextPlayTime = useRef(0)

  // Conectar al WebSocket cuando el componente se monta
  useEffect(() => {
    connectWebSocket()

    // Limpiar conexión al desmontar
    return () => {
      if (ws.current) {
        ws.current.close()
      }
    }
  }, [])

  // Auto-scroll al último mensaje
  useEffect(() => {
    scrollToBottom()
  }, [messages])

  const connectWebSocket = () => {
    try {
      // Conectar al servidor WebSocket usando URL de entorno
      ws.current = new WebSocket(WS_TEXT_URL)

      ws.current.onopen = () => {
        console.log('✅ Conectado al servidor WebSocket')
        setIsConnected(true)
        setConnectionStatus('Conectado')

        // Inicializar sesión con Azure AI
        console.log(`📤 Inicializando sesión para usuario: ${userId.current}`)
        ws.current.send(JSON.stringify({
          type: 'init',
          user_id: userId.current
        }))
      }

      ws.current.onmessage = (event) => {
        console.log('📥 Mensaje recibido:', event.data)

        try {
          const data = JSON.parse(event.data)

          switch(data.type) {
            case 'session_ready':
              // Sesión de Azure AI inicializada
              setSessionInitialized(true)
              setThreadId(data.thread_id)
              console.log(`✅ Sesión lista. Thread ID: ${data.thread_id}`)

              if (!data.is_new_session) {
                // Mostrar mensaje cuando se recupera historial existente
                setMessages(prev => [...prev, {
                  text: '💾 Tu historial de conversación ha sido recuperado',
                  sender: 'system'
                }])
              } else {
                // Mensaje de bienvenida para nueva sesión
                setMessages(prev => [...prev, {
                  text: '👋 ¡Hola! Soy tu asistente SIKA. ¿En qué puedo ayudarte hoy?',
                  sender: 'bot'
                }])
              }
              break

            case 'processing':
              // El asistente está procesando el mensaje
              setIsProcessing(true)
              break

            case 'bot_message':
              // Respuesta del asistente
              setIsProcessing(false)
              setMessages(prev => [...prev, {
                text: data.message,
                sender: 'bot'
              }])
              break

            case 'session_cleared':
              // Historial limpiado
              setMessages([{
                text: data.message,
                sender: 'system'
              }])
              break

            case 'error':
              // Error del servidor
              setIsProcessing(false)
              console.error('❌ Error del servidor:', data.message)
              setMessages(prev => [...prev, {
                text: `⚠️ Error: ${data.message}`,
                sender: 'error'
              }])
              break

            default:
              console.warn('⚠️ Tipo de mensaje desconocido:', data.type)
          }
        } catch (error) {
          console.error('❌ Error al parsear mensaje:', error)
          setIsProcessing(false)
        }
      }

      ws.current.onerror = (error) => {
        console.error('❌ Error de WebSocket:', error)
        setConnectionStatus('Error de conexión')
        setIsConnected(false)
        setSessionInitialized(false)
      }

      ws.current.onclose = () => {
        console.log('🔌 Desconectado del servidor')
        setIsConnected(false)
        setSessionInitialized(false)
        setConnectionStatus('Desconectado')

        // Intentar reconectar después de 3 segundos
        setTimeout(() => {
          console.log('🔄 Intentando reconectar...')
          setConnectionStatus('Reconectando...')
          connectWebSocket()
        }, 3000)
      }
    } catch (error) {
      console.error('❌ Error al conectar WebSocket:', error)
      setConnectionStatus('Error al conectar')
    }
  }

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const handleSendMessage = () => {
    if (!inputText.trim()) return

    if (!sessionInitialized) {
      alert('⏳ Esperando inicialización de sesión...')
      return
    }

    if (isConnected && ws.current) {
      // Añadir mensaje del usuario a la UI
      setMessages(prev => [...prev, { text: inputText, sender: 'user' }])

      // Activar indicador de procesamiento
      setIsProcessing(true)

      // Enviar mensaje al servidor con el protocolo correcto
      const messageData = {
        type: 'message',
        message: inputText
      }

      console.log('📤 Enviando mensaje:', inputText)
      ws.current.send(JSON.stringify(messageData))
      setInputText('')
    } else {
      alert('❌ No hay conexión con el servidor. Intentando reconectar...')
      connectWebSocket()
    }
  }

  const handleClearSession = () => {
    if (!sessionInitialized) return

    const confirmClear = window.confirm(
      '¿Estás seguro de que deseas eliminar todo el historial de conversación? Esta acción no se puede deshacer.'
    )

    if (confirmClear && isConnected && ws.current) {
      console.log('🗑️ Limpiando sesión...')
      ws.current.send(JSON.stringify({
        type: 'clear_session'
      }))
    }
  }

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSendMessage()
    }
  }

  // ===== FUNCIONES DE MODO VOZ =====

  // Función para reproducir audio PCM recibido del backend (basado en test_websocket.html)
  const playAudioChunk = (arrayBuffer) => {
    try {
      if (!playbackContext.current) {
        playbackContext.current = new (window.AudioContext || window.webkitAudioContext)({
          sampleRate: 24000
        })
        nextPlayTime.current = playbackContext.current.currentTime
        console.log('🔊 Contexto de audio de reproducción inicializado')
      }

      // Convertir ArrayBuffer a Int16Array (PCM 16-bit)
      const pcmData = new Int16Array(arrayBuffer)

      // Convertir PCM 16-bit a Float32Array para Web Audio API
      const audioData = new Float32Array(pcmData.length)
      for (let i = 0; i < pcmData.length; i++) {
        audioData[i] = pcmData[i] / (pcmData[i] < 0 ? 0x8000 : 0x7FFF)
      }

      // Crear AudioBuffer
      const audioBuffer = playbackContext.current.createBuffer(1, audioData.length, 24000)
      audioBuffer.getChannelData(0).set(audioData)

      // Crear source
      const source = playbackContext.current.createBufferSource()
      source.buffer = audioBuffer
      source.connect(playbackContext.current.destination)

      // Calcular cuándo debe empezar este chunk
      const now = playbackContext.current.currentTime

      // Si nextPlayTime está en el pasado, ajustarlo al presente
      if (nextPlayTime.current < now) {
        nextPlayTime.current = now
      }

      // Reproducir en el momento correcto (secuencialmente)
      source.start(nextPlayTime.current)

      // Actualizar nextPlayTime para el siguiente chunk
      const duration = audioBuffer.duration
      nextPlayTime.current += duration

      console.log(`🔊 Audio programado en ${nextPlayTime.current.toFixed(3)}s, duración: ${duration.toFixed(3)}s`)

    } catch (error) {
      console.error('❌ Error al reproducir audio:', error)
    }
  }

  const connectVoiceWebSocket = () => {
    try {
      // Conectar al servidor de voz usando URL de entorno
      voiceWs.current = new WebSocket(WS_VOICE_URL)
      voiceWs.current.binaryType = 'arraybuffer'  // ✅ CRÍTICO: Recibir audio como ArrayBuffer

      voiceWs.current.onopen = () => {
        console.log('✅ Conectado al servidor de voz')
        setVoiceConnectionStatus('Conectado')

        // Inicializar sesión de voz
        voiceWs.current.send(JSON.stringify({
          type: 'init_voice',
          user_id: userId.current
        }))
      }

      voiceWs.current.onmessage = (event) => {
        // Detectar si es mensaje binario (audio) o texto (JSON)
        if (event.data instanceof ArrayBuffer) {
          // Es audio binario - reproducirlo inmediatamente
          console.log('📢 Audio recibido:', event.data.byteLength, 'bytes')
          playAudioChunk(event.data)
        } else {
          // Es mensaje JSON
          try {
            const data = JSON.parse(event.data)
            console.log('📥 Evento de voz:', data)

            switch(data.type) {
              case 'voice_session_ready':
                console.log(`✅ Sesión de voz lista`)
                setMessages(prev => [...prev, {
                  text: '🎤 Modo voz activado. Puedes hablar ahora.',
                  sender: 'system'
                }])
                break

              case 'user_transcript':
                // Transcripción de lo que dijo el usuario
                setMessages(prev => [...prev, {
                  text: data.text,
                  sender: 'user'
                }])
                // Activar indicador de procesamiento
                setIsVoiceProcessing(true)
                break

              case 'agent_text':
              case 'agent_transcript':
                // Respuesta del agente (texto)
                setIsVoiceProcessing(false)
                setMessages(prev => [...prev, {
                  text: data.text,
                  sender: 'bot'
                }])
                break

              case 'voice_session_stopped':
                console.log('Sesión de voz detenida')
                break

              case 'error':
                console.error('❌ Error de voz:', data.message)
                setIsVoiceProcessing(false)
                setMessages(prev => [...prev, {
                  text: `⚠️ Error: ${data.message}`,
                  sender: 'error'
                }])
                break

              default:
                console.warn('⚠️ Tipo de evento de voz desconocido:', data.type)
            }
          } catch (error) {
            console.error('❌ Error al parsear mensaje de voz:', error)
          }
        }
      }

      voiceWs.current.onerror = (error) => {
        console.error('❌ Error de WebSocket de voz:', error)
        setVoiceConnectionStatus('Error de conexión')
      }

      voiceWs.current.onclose = () => {
        console.log('🔌 Desconectado del servidor de voz')
        setVoiceConnectionStatus('Desconectado')
      }

    } catch (error) {
      console.error('❌ Error al conectar WebSocket de voz:', error)
      setVoiceConnectionStatus('Error al conectar')
    }
  }

  const resetAudioPlayback = () => {
    // Resetear el tiempo de reproducción cuando el usuario empieza a hablar
    if (playbackContext.current) {
      nextPlayTime.current = playbackContext.current.currentTime
    }
    console.log('🔄 Audio playback reseteado')
  }

  const startVoiceCapture = async () => {
    try {
      // Resetear reproducción cuando el usuario empieza a hablar
      resetAudioPlayback()

      // Solicitar acceso al micrófono
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          sampleRate: 24000,
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true
        }
      })

      audioStream.current = stream

      // Crear AudioContext para procesar audio
      audioContext.current = new (window.AudioContext || window.webkitAudioContext)({
        sampleRate: 24000
      })

      const source = audioContext.current.createMediaStreamSource(stream)
      const processor = audioContext.current.createScriptProcessor(2048, 1, 1)

      processor.onaudioprocess = (e) => {
        if (voiceWs.current && voiceWs.current.readyState === WebSocket.OPEN) {
          const inputData = e.inputBuffer.getChannelData(0)

          // Convertir Float32Array a Int16Array (PCM 16-bit)
          const int16Data = new Int16Array(inputData.length)
          for (let i = 0; i < inputData.length; i++) {
            const s = Math.max(-1, Math.min(1, inputData[i]))
            int16Data[i] = s < 0 ? s * 0x8000 : s * 0x7FFF
          }

          // Enviar datos de audio como binario
          voiceWs.current.send(int16Data.buffer)
        }
      }

      source.connect(processor)
      processor.connect(audioContext.current.destination)

      console.log('🎤 Captura de voz iniciada')

    } catch (error) {
      console.error('❌ Error al iniciar captura de voz:', error)
      alert('No se pudo acceder al micrófono. Verifica los permisos.')
      stopVoiceMode()
    }
  }

  const stopVoiceCapture = () => {
    // Detener tracks de audio
    if (audioStream.current) {
      audioStream.current.getTracks().forEach(track => track.stop())
      audioStream.current = null
    }

    // Cerrar AudioContext
    if (audioContext.current) {
      audioContext.current.close()
      audioContext.current = null
    }

    console.log('🛑 Captura de voz detenida')
  }

  const stopVoiceMode = () => {
    // Detener captura de audio
    stopVoiceCapture()

    // Cerrar contexto de reproducción y resetear tiempo
    nextPlayTime.current = 0
    if (playbackContext.current) {
      playbackContext.current.close()
      playbackContext.current = null
    }

    // Cerrar WebSocket de voz
    if (voiceWs.current) {
      voiceWs.current.send(JSON.stringify({ type: 'stop_voice' }))
      voiceWs.current.close()
      voiceWs.current = null
    }

    setIsVoiceMode(false)
    setIsRecording(false)
    setIsVoiceProcessing(false)
    setVoiceConnectionStatus('Desconectado')

    setMessages(prev => [...prev, {
      text: '🎤 Modo voz desactivado',
      sender: 'system'
    }])
  }

  const handleMicrophoneClick = async () => {
    if (isVoiceMode) {
      // Desactivar modo voz
      stopVoiceMode()
    } else {
      // Activar modo voz
      setIsVoiceMode(true)
      setIsRecording(true)

      // Conectar al WebSocket de voz
      connectVoiceWebSocket()

      // Esperar un poco para que se establezca la conexión
      setTimeout(() => {
        startVoiceCapture()
      }, 500)
    }
  }

  return (
    <div className="chat-container">
      {/* Header */}
      <div className="chat-header">
        <div className="chat-title">
          <span>SIKA AI Assistant</span>
          {threadId && (
            <span className="thread-id" title={`Session ID: ${threadId}`}>
              #{threadId.substring(0, 8)}
            </span>
          )}
        </div>
        <div className="header-actions">
          <button
            className="clear-history-btn"
            onClick={handleClearSession}
            disabled={!sessionInitialized || messages.length === 0}
            title="Limpiar historial"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
              <path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </button>
          <div className={`connection-status ${isConnected ? 'connected' : 'disconnected'}`}>
            <span className="status-dot"></span>
            <span className="status-text">{connectionStatus}</span>
          </div>
        </div>
      </div>

      {/* Messages Area */}
      <div className="messages-container">
        {messages.length === 0 && !isProcessing ? (
          <div className="empty-state">
            <h1>¿En qué estás trabajando?</h1>
            <p className="subtitle">Pregúntame lo que necesites sobre productos SIKA</p>
          </div>
        ) : (
          <div className="messages-list">
            {messages.map((message, index) => (
              <div key={index} className={`message ${message.sender}`}>
                <div className="message-content">{message.text}</div>
              </div>
            ))}
            {(isProcessing || isVoiceProcessing) && (
              <div className="message processing">
                <div className="message-content">
                  <div className="typing-indicator">
                    <span></span>
                    <span></span>
                    <span></span>
                  </div>
                  {isVoiceMode ? 'SIKA está pensando...' : 'Procesando tu mensaje...'}
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>
        )}
      </div>

      {/* Input Area */}
      <div className="input-container">
        <div className="input-wrapper">
          <button className="add-btn" title="Añadir archivo">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M12 5V19M5 12H19" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
            </svg>
          </button>

          <input
            type="text"
            className="message-input"
            placeholder="Pregunta lo que quieras"
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyPress={handleKeyPress}
          />

          <button
            className={`microphone-btn ${isRecording ? 'recording' : ''}`}
            onClick={handleMicrophoneClick}
            title="Usar micrófono"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M12 1C10.34 1 9 2.34 9 4V12C9 13.66 10.34 15 12 15C13.66 15 15 13.66 15 12V4C15 2.34 13.66 1 12 1Z" stroke="currentColor" strokeWidth="2"/>
              <path d="M19 10V12C19 15.87 15.87 19 12 19C8.13 19 5 15.87 5 12V10" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              <path d="M12 19V23M8 23H16" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
            </svg>
          </button>

          <button
            className="send-btn"
            onClick={handleSendMessage}
            disabled={!inputText.trim() || !sessionInitialized || isProcessing}
            title={isProcessing ? "Procesando..." : "Enviar mensaje"}
          >
            {isProcessing ? (
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" className="spinner">
                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2" opacity="0.25"/>
                <path d="M12 2a10 10 0 0110 10" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              </svg>
            ) : (
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M7 11L12 6L17 11M12 18V7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

export default ChatInterface
