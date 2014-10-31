<?php

define('PATH', dirname(realpath(__FILE__)));
$s_bootstrap_file = PATH . '/bootstrap.sh';

$s_uuid = NULL;
isset($_GET['uuid']) && $s_uuid = $_GET['uuid'];

$s_content = @file_get_contents($s_bootstrap_file);

// Repace UUID with uuid (and disable log to a file)
if($s_uuid) {
  $s_content = str_replace('UUID=','UUID=' . $s_uuid,$s_content);
  $s_content = str_replace('exec > ${LOG_FILE} 2>&1','',$s_content);
}

ob_clean();
header('Cache-Control: must-revalidate, post-check=0, pre-check=0');
header("Pragma: no-cache");
header("Content-Type:text/plain; charset=utf-8");
header('Content-Length: ' . strlen($s_content));

echo $s_content;
