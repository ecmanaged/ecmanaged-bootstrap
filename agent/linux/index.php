<?php

define('PATH', dirname(realpath(__FILE__)));
$s_bootstrap_file = PATH . '/bootstrap.sh';

$s_uuid = $s_userdata = NULL;
isset($_GET['uuid']) && $s_uuid = $_GET['uuid'];
isset($_GET['userdata']) && $s_userdata = $_GET['userdata'];

$s_content = @file_get_contents($s_bootstrap_file);

// Repace UUID with uuid (and disable log to a file)
$s_content = str_replace('UUID=','UUID=' . $s_uuid,$s_content);
$s_content = str_replace('exec > ${LOG_FILE} 2>&1','',$s_content);

// Repace Userdata (this is default userdata)
if($s_userdata) {
  try {
    @base64_decode($s_userdata);
    $s_content = str_replace('ZWNobyAnTm8gdXNlciBwcm92aWRlZCBzY3JpcHQnCg==',$s_userdata,$s_content);

  } catch (Exception $e) { }
}

ob_clean();
header('Cache-Control: must-revalidate, post-check=0, pre-check=0');
header("Pragma: no-cache");
header("Content-Type:text/plain; charset=utf-8");
header('Content-Length: ' . strlen($s_content));

echo $s_content;
