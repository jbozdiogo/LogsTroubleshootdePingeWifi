Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:running = $false
$script:logPath = $null
$script:sequence = 0
$script:sent = 0
$script:received = 0
$script:lost = 0
$script:pinger = New-Object System.Net.NetworkInformation.Ping

$form = New-Object System.Windows.Forms.Form
$form.Text = "Monitor de Conectividade"
$form.Size = New-Object System.Drawing.Size(560, 420)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$lblDestino = New-Object System.Windows.Forms.Label
$lblDestino.Text = "Destino:"
$lblDestino.Location = New-Object System.Drawing.Point(20, 22)
$lblDestino.AutoSize = $true
$form.Controls.Add($lblDestino)

$txtDestino = New-Object System.Windows.Forms.TextBox
$txtDestino.Text = "1.1.1.1"
$txtDestino.Location = New-Object System.Drawing.Point(100, 18)
$txtDestino.Size = New-Object System.Drawing.Size(210, 28)
$form.Controls.Add($txtDestino)

$btnIniciar = New-Object System.Windows.Forms.Button
$btnIniciar.Text = "Iniciar"
$btnIniciar.Location = New-Object System.Drawing.Point(330, 16)
$btnIniciar.Size = New-Object System.Drawing.Size(90, 32)
$form.Controls.Add($btnIniciar)

$btnParar = New-Object System.Windows.Forms.Button
$btnParar.Text = "Parar"
$btnParar.Location = New-Object System.Drawing.Point(430, 16)
$btnParar.Size = New-Object System.Drawing.Size(90, 32)
$btnParar.Enabled = $false
$form.Controls.Add($btnParar)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Status: parado"
$lblStatus.Location = New-Object System.Drawing.Point(20, 63)
$lblStatus.AutoSize = $true
$form.Controls.Add($lblStatus)

$lblContadores = New-Object System.Windows.Forms.Label
$lblContadores.Text = "Enviados: 0  Recebidos: 0  Perdidos: 0"
$lblContadores.Location = New-Object System.Drawing.Point(20, 90)
$lblContadores.AutoSize = $true
$form.Controls.Add($lblContadores)

$txtSaida = New-Object System.Windows.Forms.TextBox
$txtSaida.Location = New-Object System.Drawing.Point(20, 125)
$txtSaida.Size = New-Object System.Drawing.Size(500, 215)
$txtSaida.Multiline = $true
$txtSaida.ScrollBars = "Vertical"
$txtSaida.ReadOnly = $true
$txtSaida.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtSaida)

$lblArquivo = New-Object System.Windows.Forms.Label
$lblArquivo.Text = "O arquivo será salvo em C:\Temp"
$lblArquivo.Location = New-Object System.Drawing.Point(20, 352)
$lblArquivo.Size = New-Object System.Drawing.Size(500, 24)
$form.Controls.Add($lblArquivo)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000

function Atualizar-Contadores {
    $lblContadores.Text = "Enviados: $script:sent  Recebidos: $script:received  Perdidos: $script:lost"
}

function Registrar-Linha([string]$linha) {
    $txtSaida.AppendText($linha + [Environment]::NewLine)
    if ($txtSaida.Lines.Count -gt 200) {
        $txtSaida.Lines = $txtSaida.Lines[-150..-1]
        $txtSaida.SelectionStart = $txtSaida.Text.Length
        $txtSaida.ScrollToCaret()
    }
    Add-Content -Path $script:logPath -Value $linha -Encoding UTF8
}

$timer.Add_Tick({
    if (-not $script:running) { return }

    $destino = $txtDestino.Text.Trim()
    $script:sequence++
    $script:sent++
    $hora = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

    try {
        $resposta = $script:pinger.Send($destino, 900)
        if ($resposta.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            $script:received++
            $linha = "$hora Resposta de $($resposta.Address): tempo=$($resposta.RoundtripTime)ms TTL=$($resposta.Options.Ttl)"
        } else {
            $script:lost++
            $linha = "$hora Falha: $($resposta.Status)"
        }
    } catch {
        $script:lost++
        $linha = "$hora Erro: $($_.Exception.Message)"
    }

    Registrar-Linha $linha
    Atualizar-Contadores
})

$btnIniciar.Add_Click({
    $destino = $txtDestino.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($destino)) {
        [System.Windows.Forms.MessageBox]::Show("Informe um IP ou nome de destino.", "Destino obrigatório")
        return
    }

    $pasta = "C:\Temp"
    New-Item -ItemType Directory -Path $pasta -Force | Out-Null
    $nomeSeguro = $destino -replace '[^a-zA-Z0-9._-]', '_'
    $script:logPath = Join-Path $pasta ("monitor_{0}_{1}.txt" -f $nomeSeguro, (Get-Date -Format "yyyyMMdd_HHmmss"))
    $script:sent = 0
    $script:received = 0
    $script:lost = 0
    $script:sequence = 0
    $script:running = $true

    $txtSaida.Clear()
    $txtDestino.Enabled = $false
    $btnIniciar.Enabled = $false
    $btnParar.Enabled = $true
    $lblStatus.Text = "Status: monitorando $destino"
    $lblArquivo.Text = "Arquivo: $script:logPath"
    Registrar-Linha ("===== Início {0} | Destino: {1} =====" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $destino)
    Atualizar-Contadores
    $timer.Start()
})

$btnParar.Add_Click({
    if (-not $script:running) { return }
    $timer.Stop()
    $script:running = $false
    Registrar-Linha ("===== Fim {0} | Enviados: {1} | Recebidos: {2} | Perdidos: {3} =====" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $script:sent, $script:received, $script:lost)
    $lblStatus.Text = "Status: parado"
    $txtDestino.Enabled = $true
    $btnIniciar.Enabled = $true
    $btnParar.Enabled = $false
    [System.Windows.Forms.MessageBox]::Show("Coleta encerrada.`nArquivo salvo em:`n$script:logPath", "Coleta concluída")
})

$form.Add_FormClosing({
    if ($script:running) {
        $timer.Stop()
        $script:running = $false
        Registrar-Linha ("===== Encerrado ao fechar {0} | Enviados: {1} | Recebidos: {2} | Perdidos: {3} =====" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $script:sent, $script:received, $script:lost)
    }
    $script:pinger.Dispose()
})

[void]$form.ShowDialog()
