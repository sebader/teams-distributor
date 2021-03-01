$n = 10
$urls = @()
$tail = "a" * 1

for($i = 0; $i -lt $n; $i++){
    $url = "https://teams.microsoft.com/l/meetup-join/$i/$tail"
    $urls += $url
}

$result = $urls -join "`n"
Out-File -FilePath ./urls.txt -Encoding utf8 -InputObject $result