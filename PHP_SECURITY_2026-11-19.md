# PHP 安全更新核查（2026-11-19）

## 官方发布与版本

已核对 [PHP 首页](https://www.php.net/index.php)、[支持周期](https://www.php.net/supported-versions.php)、[ChangeLog](https://www.php.net/ChangeLog-8.php) 与 [源码下载及 SHA-256](https://www.php.net/downloads.php?source=Y)。11 月 19 日安全发布真实存在；不能将最高 CRITICAL 等同于默认 LNMP 可被直接远程利用。

| 分支 | 仓库原版本 | 本次固定版本 | 状态 |
| --- | --- | --- | --- |
| 7.4 | 7.4.33 | 保留 | EOL；已有补丁仅覆盖 10 月两项漏洞 |
| 8.1 | 8.1.34 | 保留 | EOL；已有补丁仅覆盖 10 月两项漏洞 |
| 8.2 | 8.2.35 | 8.2.36 | 安全支持至 2026-12-31 |
| 8.3 | 8.3.36 | 8.3.37 | 安全支持至 2027-12-31 |
| 8.4 | 8.4.27 | 8.4.28 | 安全支持至 2028-12-31 |
| 8.5 | 8.5.12 | 8.5.13 | 安全支持至 2029-12-31 |

versions.txt 固定官方 tar.gz SHA-256。Download_src 对这四个固定包（含已有缓存）校验，升级脚本在解包前也校验。缺失校验值、非法值、内容不匹配均停止；不会自动删除用户缓存。其他版本与其他依赖维持原流程，**不能认为任意手动输入的版本都已校验**。

## 漏洞条件与仓库影响

下表“8.2–8.5”指各分支从 .0 起到上述修复版本之前的官方公告范围；EOL 版本未列入范围不代表安全。

| CVE | 官方证据、受影响范围及触发条件 | 本仓库判断 |
| --- | --- | --- |
| 2026-129474 | [公告](https://github.com/php/php-src/security/advisories/GHSA-8mjj-2r7p-4hg2)：8.5.0–8.5.12；魔术方法调用时致命错误回溯，演示链要求 fatal_error_backtraces=1、zend.exception_ignore_args=0 和应用可达路径 | 使用 php.ini-production，ignore_args=1 阻断已演示路径；仍升级。8.2–8.4 底层问题存在，但公告未确认远程触发，未纳入受影响范围 |
| 2026-129182 | [公告](https://github.com/php/php-src/security/advisories/GHSA-2fjv-p558-g82m)：8.5.0–8.5.12；关闭请求后配置恢复引发致命诊断，下一请求在初始化前再次诊断 | 默认模板未发现所述配置组合；FPM 还需前端传入能产生诊断的 PHP_VALUE/PHP_ADMIN_VALUE。关闭 fatal_error_backtraces 可暂缓，升级修复 |
| 2026-129496 | [公告](https://github.com/php/php-src/security/advisories/GHSA-gr4f-wgx5-jpfv)：8.2–8.5；NTS 启动晚期诊断写入 PHP 文件日志，随后新 worker 的早期请求诊断访问悬空时区缓存 | 默认 Asia/Shanghai 有效，FPM 自身 error_log 不等于 PHP 文件日志；不能仅凭 FPM 日志开启认定可利用，须检查部署覆盖项 |
| 2026-129291 | [公告](https://github.com/php/php-src/security/advisories/GHSA-jm4m-qfqx-967m)：8.2.7–8.2.35、其余 8.3–8.5；需 worker 内代码执行、epoll、catch_workers_output 及进程/管道时序 | 模板原为 yes，root master 下可提权；8.1.20 也引入此路径，8.1.34 需缓解。本次将其新安装模板设为 no，丢失 worker stdout/stderr 捕获 |
| 2026-129292 | [公告](https://github.com/php/php-src/security/advisories/GHSA-3mg3-cr28-46gc)：8.2–8.5；元数据污染 scoreboard，运维浏览 full&html 状态页触发 XSS | pm.status_path 开启；Nginx 限制 127.0.0.1 仍不能阻止通过普通业务请求植入数据。更新后再使用完整 HTML 状态输出 |
| 2026-126714 | [公告](https://github.com/php/php-src/security/advisories/GHSA-fm2m-fjf5-v3cp)：8.2–8.5；files 会话写入被中断留下旧后缀，攻击者影响会话内容且存在反序列化 gadget | 禁用上传进度只移除一个输入入口，不能消除应用自己保存用户数据的路径 |
| 2026-115560 | [公告](https://github.com/php/php-src/security/advisories/GHSA-658j-r8rw-q6mx)：8.2–8.5；上传进度写入格式与读取格式不一致，共享 session ID/存储/权限及 gadget | 不要求运行时切换格式，多个应用/池共享会话也可能满足。7.4/8.1 新池加 php_admin_flag 禁用上传进度；不能宣称完整修复 |
| 2026-129481 | [公告](https://github.com/php/php-src/security/advisories/GHSA-g3vh-838c-65v7)：8.3–8.5；会话销毁回调致命错误，后续请求复用悬空脚本文件名 | pm.max_requests=2048 允许复用；上传进度关闭和启用 OPcache 都不能完整缓解。8.2 不含该字段 |
| 2026-129538 | [ChangeLog](https://www.php.net/ChangeLog-8.php)：CGI PATH_INFO 修正越界读写 | 对应 GHSA 页面本次返回 404；未独立核实完整版本范围和细节。不能直接套用到 PHP-FPM |
| 2026-129501 | [ChangeLog](https://www.php.net/ChangeLog-8.php)：DOM XML 序列化 double-free | 对应 GHSA 页面本次返回 404；完整范围和触发条件待核实 |
| 2026-129289 | [ChangeLog](https://www.php.net/ChangeLog-8.php)：FPM 未读请求体导致请求走私 | 对应 GHSA 页面本次返回 404；未确认前端、连接复用等必要条件，不能声称默认 Nginx 可利用 |

其他已读官方公告：
- [2026-128090](https://github.com/php/php-src/security/advisories/GHSA-68fq-fh7h-f8gr)：8.2–8.5，攻击者可替换 OpenSSL 签名 Phar 且应用依赖旁置可信公钥时，降级签名算法绕过认证；问题历史可追溯至 5.3。
- [2026-15353](https://github.com/php/php-src/security/advisories/GHSA-q23r-hr55-xmpg)：8.2–8.5，SOAP 非法 arraySize，应用暴露解码结果时可泄露少量堆数据。
- [2026-129506](https://github.com/php/php-src/security/advisories/GHSA-4646-p932-gw34)：8.2–8.5，SOAP/WSDL/schema 中 DTD 与属性实体引用造成 UAF/崩溃；未证实 RCE。
- [2026-128064](https://github.com/php/php-src/security/advisories/GHSA-f6gg-rchx-xw8j)：8.2–8.5，PHP 流包装器处理含大写 S 的 HTTPS/FTPS 或重定向目标时可能明文发送数据；并非 cURL 问题。
- [2026-127960](https://github.com/php/php-src/security/advisories/GHSA-mmf9-xm3v-hg2x)：8.2.28、8.3.18、8.4.5 起至本次修复前及 8.5.0–8.5.12；恶意上游响应的折叠 HTTP 头造成 CPU DoS。
- [2026-129438](https://github.com/php/php-src/security/advisories/GHSA-mg3p-mxj9-g2mm)：8.5.0–8.5.12；RFC3986 URI 序列化约 2 GiB 输入边界，普通 parse_url 不涉及。更新 uriparser 本身不够。
- ChangeLog 另列 uriparser CVE-2026-48841；本次未独立核查该依赖 CVE 细节。

## mphp、旧版补丁与部署

include/mphp.sh 直接调用各版本 Install_PHPXX，因此共享 versions.txt、下载与 7.4/8.1 补丁入口，也继承本次安装配置。并存版本使用独立安装目录和 socket；这不保证应用的 session.save_path 隔离。无需复制安全补丁逻辑到 mphp.sh。

PHP-FPM 使用 Unix socket，listen.mode=0666；listen.allowed_clients=127.0.0.1 仅对 TCP 有效，不限制 Unix socket 的本地客户端。该权限增加本地进程直接访问 FastCGI 的面，应结合 Nginx 用户/组另行收紧；本次未改变以免破坏既有跨用户连接。模板使用动态进程池、有限 memory_limit、100M post_max_size、50M upload_max_filesize；这些都不能代替补丁，不采用 memory_limit=-1 的全局改动。

include/php_security_patch.sh 限定 7.4.33/8.0.30/8.1.34，应用 10 月 CVE-2026-109618/109619 的上游最小回移，不覆盖 11 月新增问题。其下载使用动态 GitHub compare；没有固定内容校验，不能作为经过完整安全审计的长期维护方案。

回移评估：
- 8.1 的 FPM 事件注销/描述符生命周期修复有明确对应代码，适合独立评估回移，但仍需对照正式修复提交、原始发行 tarball + 现有 10 月补丁做严格 dry-run、构建与并发回归。本次使用官方建议关闭输出捕获缓解，未加入未经验证的 C 补丁。
- 7.4 未处于公告指出的 8.1.20 起引入的 FPM 路径，不因此认定其他漏洞不存在。
- 会话文件截断、流协议大小写检查和 Phar 校验等可逐项研究；会话状态清理、时区缓存、DOM/SOAP 涉及版本间生命周期差异，不适合直接整批套用 8.2 diff。
- PHP 8.5 独有回溯/URI API 问题不应盲目回移到旧版。推荐升级受支持分支；需要继续运行旧版时采用能提供完整回归的维护发行版。

本次仅更改安装模板，不在线修改已有服务。已有 7.4/8.1 需在各池配置应用上传进度禁用项；8.1 另关闭 catch_workers_output，先 php-fpm -t 再重启所有 worker。升级源码通常保留已有 php.ini/池配置，应复核有效配置与应用兼容性。上传进度功能会停止，8.1 worker 标准输出/错误捕获会关闭。

## 验证

- 四个官方 tar.gz 实际下载并通过仓库校验函数核对 SHA-256。
- bash -n 检查下载、升级、mphp 及相关 PHP 安装脚本。
- bash tests/php-archive.sh：实际运行隔离测试，覆盖损坏缓存拒绝、有效缓存通过、缺失/非法哈希拒绝和其他包兼容。
- git diff --check；保留原文件换行格式，无批量转换。
- 未运行 Linux PHP 编译、FPM 配置加载/启动、实际 Nginx 请求、漏洞复现或 EOL C 补丁回归；Windows Bash 检查不能替代这些验证。
- 未提交、未推送。原有未跟踪 PROJECT_MEMORY.md 未修改。
