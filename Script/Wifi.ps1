Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:running = $false
$script:logPath = $null

$form = New-Object System.Windows.Forms.Form
$form.Text = "Petrobras Wi-Fi Monitor"
$form.Size = New-Object System.Drawing.Size(690, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Text = "Monitoramento do Wi-Fi durante a reuniao"
$lblTitulo.Location = New-Object System.Drawing.Point(20, 18)
$lblTitulo.Size = New-Object System.Drawing.Size(390, 28)
$lblTitulo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
$form.Controls.Add($lblTitulo)

$btnIniciar = New-Object System.Windows.Forms.Button
$btnIniciar.Text = "Iniciar"
$btnIniciar.Location = New-Object System.Drawing.Point(455, 15)
$btnIniciar.Size = New-Object System.Drawing.Size(90, 34)
$form.Controls.Add($btnIniciar)

$btnParar = New-Object System.Windows.Forms.Button
$btnParar.Text = "Parar"
$btnParar.Location = New-Object System.Drawing.Point(555, 15)
$btnParar.Size = New-Object System.Drawing.Size(90, 34)
$btnParar.Enabled = $false
$form.Controls.Add($btnParar)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Status: parado"
$lblStatus.Location = New-Object System.Drawing.Point(20, 62)
$lblStatus.AutoSize = $true
$form.Controls.Add($lblStatus)

$lblAtual = New-Object System.Windows.Forms.Label
$lblAtual.Text = "BSSID: -   Canal: -   RSSI: -   Sinal: -"
$lblAtual.Location = New-Object System.Drawing.Point(20, 90)
$lblAtual.Size = New-Object System.Drawing.Size(625, 26)
$form.Controls.Add($lblAtual)

$txtSaida = New-Object System.Windows.Forms.TextBox
$txtSaida.Location = New-Object System.Drawing.Point(20, 125)
$txtSaida.Size = New-Object System.Drawing.Size(625, 285)
$txtSaida.Multiline = $true
$txtSaida.ScrollBars = "Vertical"
$txtSaida.ReadOnly = $true
$txtSaida.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtSaida)

$lblArquivo = New-Object System.Windows.Forms.Label
$lblArquivo.Text = "O arquivo sera salvo em C:\Temp"
$lblArquivo.Location = New-Object System.Drawing.Point(20, 425)
$lblArquivo.Size = New-Object System.Drawing.Size(625, 40)
$form.Controls.Add($lblArquivo)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000

function Obter-Valor([string[]]$linhas, [string]$padrao) {
    $linha = $linhas | Where-Object { $_ -match $padrao } | Select-Object -First 1
    if ($linha -and $linha -match ':\s*(.+)$') { return $matches[1].Trim() }
    return "-"
}

function Registrar-Linha([string]$linha) {
    $txtSaida.AppendText($linha + [Environment]::NewLine)
    $txtSaida.SelectionStart = $txtSaida.Text.Length
    $txtSaida.ScrollToCaret()
    Add-Content -Path $script:logPath -Value $linha -Encoding UTF8
}

function Coletar-Wifi {
    $hora = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $dados = netsh wlan show interfaces 2>&1

    $estado = Obter-Valor $dados '^\s*Estado\s*:'
    $ssid = Obter-Valor $dados '^\s*SSID\s*:'
    $bssid = Obter-Valor $dados '^\s*AP BSSID\s*:'
    $banda = Obter-Valor $dados '^\s*Banda\s*:'
    $canal = Obter-Valor $dados '^\s*Canal\s*:'
    $rx = Obter-Valor $dados '^\s*Taxa de recep'
    $tx = Obter-Valor $dados '^\s*Taxa de transmiss'
    $sinal = Obter-Valor $dados '^\s*Sinal\s*:'
    $rssi = Obter-Valor $dados '^\s*Rssi\s*:'

    $resumo = "$hora | Estado=$estado | SSID=$ssid | BSSID=$bssid | Banda=$banda | Canal=$canal | RX=$rx Mbps | TX=$tx Mbps | Sinal=$sinal | RSSI=$rssi dBm"
    Registrar-Linha $resumo
    $lblAtual.Text = "BSSID: $bssid   Canal: $canal   RSSI: $rssi dBm   Sinal: $sinal"
}

$timer.Add_Tick({
    if ($script:running) { Coletar-Wifi }
})

$btnIniciar.Add_Click({
    $pasta = "C:\Temp"
    New-Item -ItemType Directory -Path $pasta -Force | Out-Null
    $script:logPath = Join-Path $pasta ("petrobras_wifi_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    $script:running = $true

    $txtSaida.Clear()
    $btnIniciar.Enabled = $false
    $btnParar.Enabled = $true
    $lblStatus.Text = "Status: monitorando a cada 5 segundos"
    $lblArquivo.Text = "Arquivo: $script:logPath"
    Registrar-Linha ("===== Inicio {0} =====" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"))
    Coletar-Wifi
    $timer.Start()
})

$btnParar.Add_Click({
    if (-not $script:running) { return }
    $timer.Stop()
    $script:running = $false
    Registrar-Linha ("===== Fim {0} =====" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"))
    $lblStatus.Text = "Status: parado"
    $btnIniciar.Enabled = $true
    $btnParar.Enabled = $false
    [System.Windows.Forms.MessageBox]::Show("Coleta encerrada.`nArquivo salvo em:`n$script:logPath", "Coleta concluida")
})

$form.Add_FormClosing({
    if ($script:running) {
        $timer.Stop()
        $script:running = $false
        Registrar-Linha ("===== Encerrado ao fechar {0} =====" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"))
    }
})

[void]$form.ShowDialog()
