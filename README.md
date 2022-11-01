# SpamCode 垃圾代码生成器 

## 主要功能
1. 修改工程名
2. 修改类名前缀
3. 扫描工程中的代码，生成同等数量的 Category 文件，文件中及是同等方法数量的垃圾代码。
4. 修改 xxx.xcassets 文件夹中的 png 资源文件名。
5. 删除代码中的所有注释和空行。
## 6. 随机添加垃圾代码，修改方法名前缀!

## 使用
### 使用源码
1. 下载源码。
1. 用 Xcode 打开工程并配置参数。如图![配置参数](https://github.com/oneyian/SpamCode/raw/master/README.png)
1. 运行

### 使用二进制文件，在终端中执行 SpamCode
```
$ ./SpamCode \
/Users/imac/Desktop/App \
-deleteComments
```

### 参数说明
- *(必填)* **源码文件夹绝对路径**（如：`/Users/imac/Desktop/App`）
- **-modifyProjectName [原名称]>[新名称]** 修改工程名。程序会修改`原名称-Swift.h`、`Podfile`、`原名称-Bridging-Header.h`、`源码文件夹绝对路径`、`原名称.xcodeproj`和`原名称.xcworkspace`的名称和内容。*`Podfile`被修改后需要手动`pod install`*
- **-modifyClassNamePrefix [工程文件 xcodeproj 绝对路径] [原前缀]>[新前缀]** 修改源代码类名前缀。程序会扫描`源码文件夹绝对路径`下的 .h .swift 文件，修改文件名，修改使用该类名的代码，修改`工程文件`中的文件名。文件名有`原前缀`的会修改成`新前缀`，如：`原前缀ViewController`变成`新前缀ViewController`；没有`原前缀`的会增加`新前缀`，如：`ViewController`变成`新前缀ViewController`。
- **-spamCodeOut [垃圾代码文件输出目录] [垃圾代码方法增加的参数名]** 生成垃圾代码。程序会扫描`源码文件夹绝对路径`下的 .m .swift 文件中的类和方法，并生成`category`和`extension`文件，文件中的方法是在代码原方法的基础上增加`垃圾代码方法增加的参数名`参数。如：`-spamCodeOut /dir AppLog`，`- (void)setupKeys {}`>`- (void)setupKeysAppLog:(NSString *)appLog {}`，`- (void)foo:(NSString *)str {}`>`- (void)foo:(NSString *)str appLog:(NSString *)appLog {}`
- **-ignoreDirNames [忽略文件夹名称字符串]** 忽略这些文件夹，对`-modifyClassNamePrefix`和`-spamCodeOut`参数有效。目前只会忽略`源码文件夹绝对路径`下一级的这些目录。如：`/p/s -ignoreDirNames categorys`，那么`/p/s/categorys`会被忽略，但`/p/s/viewControllers/categorys`不会忽略。
- **-handleXcassets** 修改`xxx.xcassets`文件夹中的 png 资源文件名，同时也`Contents.json`文件中的关联名称，不会影响代码中使用图片。
- **-deleteComments** 删除工程目录下 .h .m .swift 文件中的注释和空行。

## 另外修改图片 hash 值的方法
使用 [ImageMagick](http://www.imagemagick.org/) 对 png 图片做轻量压缩，及不损失图片质量，又可改变图片文件 hash 值。方法：
1. 安装 ImageMagick，`brew install imagemagick`
2. 压缩工程目录下所有 png 文件，`find . -iname "*.png" -exec echo {} \; -exec convert {} {} \;`

## 使用经验
```
/Users/imac/Desktop/App
-ignoreDirNames Pods
-spamCodeOut /Users/imac/Desktop/App/addCode addCode
-handleXcassets
-deleteComments
```
1. 修改工程名
2. 生成垃圾代码
3. 修改 .xcassets 中的图片文件名
4. 删除工程目录下 .h .m .swift 文件中的注释和空行
5. 修改图片文件 Hash 值
6. 用别的电脑打包


## 已知问题
- 生成的垃圾代码文件可能是 .m 文件中实现的私有类，编译垃圾代码可能会报错，删除该垃圾代码 .h .m 文件即可。

