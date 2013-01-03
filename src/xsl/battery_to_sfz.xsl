<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text" omit-xml-declaration="yes" media-type="text/plain" />
	<xsl:param name="uppercaseFileNames" select="'no'" />
	<xsl:param name="pathPrefix" select="'samples/'" />
	<xsl:param name="maxEGTime" select="10" />
	<xsl:variable name='newline'><xsl:text>&#xa;</xsl:text></xsl:variable>
	<!--
		Copyright (c) 2013 Daniel Appelt
		See LICENSE file for details.
	-->
	<xsl:template match="BatteryPatch">
// <xsl:value-of select="attribute::name" />
// sfz conversion from Battery Kit v1 done by battery_to_sfz.xsl
		<xsl:apply-templates />
	</xsl:template>

	<xsl:template match="SampleSlot">
&lt;group>
// <xsl:value-of select="attribute::label" />
<!-- Convert volume value 0-1 to decibels using 10*log10() where 1 == 0dB. TODO: Note that Battery 3 has a range of -8dB to +12dB, sfz uses -144dB to +6dB. We cap this value to have 0dB at maximum. -->
// original volume: <xsl:value-of select="attribute::volume" />
volume=<xsl:call-template name="approximateLog">
	<xsl:with-param name="value" select="number(attribute::volume)" />
</xsl:call-template>

<!-- Convert pan from 0 to 1 range to -100 to 100. -->
pan=<xsl:value-of select="(number(attribute::pan)-0.5) * 200" />
output=<xsl:value-of select="number(attribute::output)" />
		<xsl:if test="number(attribute::midiChannel) &lt; 16">
lochan=<xsl:value-of select="number(attribute::midiChannel)" />
hichan=<xsl:value-of select="number(attribute::midiChannel)" />
		</xsl:if>
		<xsl:if test="number(attribute::muteGroup) &gt; 0">
group=<xsl:value-of select="number(attribute::muteGroup)" />
off_by=<xsl:value-of select="number(attribute::muteGroup)" />
		</xsl:if>
pitch_keycenter=<xsl:value-of select="attribute::rootKey" />
		<xsl:call-template name="ifStatusBit">
			<xsl:with-param name="elseValue">
<!-- Do not allow tracking of pitch by key. -->
pitch_keytrack=0<xsl:text />
			</xsl:with-param>
			<xsl:with-param name="status" select="number(attribute::status)" />
			<xsl:with-param name="index" select="3" />
		</xsl:call-template>
lokey=<xsl:value-of select="attribute::lowKey" />
hikey=<xsl:value-of select="attribute::highKey" />

<!-- Volume EG. Right now, we map Battery time values (range 0 to 127) linearly into a range of 0 to $maxEGTime seconds. amp(lifier)eg start and sustain are given in 0-100% in sfz. time values are given in float in the range 0-100 seconds.
TODO: check value mapping -->
		<xsl:call-template name="ifStatusBit">
			<xsl:with-param name="value">
ampeg_attack=<xsl:value-of select="number(attribute::vattack)*$maxEGTime div 127" />
ampeg_hold=<xsl:value-of select="number(attribute::vhold)*$maxEGTime div 127" />
ampeg_decay=<xsl:value-of select="number(attribute::vdecay)*$maxEGTime div 127" />
ampeg_sustain=<xsl:value-of select="number(attribute::vsustain)*100 div 127" />
ampeg_release=<xsl:value-of select="number(attribute::vrelease)*$maxEGTime div 127" />
			</xsl:with-param>
			<xsl:with-param name="elseValue">
<!-- If no volume envelope is specified, one shot mode is used in Battery. -->
loop_mode=one_shot<xsl:text />
			</xsl:with-param>
			<xsl:with-param name="status" select="number(attribute::status)" />
			<xsl:with-param name="index" select="5" />
		</xsl:call-template>

<!-- Pitch seems to be given in the range 0 to 2(??) in Battery 1 and covers -3 to 3 octaves in Battery 3!?
	0 -> -3 octaves = -36, 1 -> 0, 2 -> 36 -->
transpose=<xsl:value-of select="round(36 * (number(attribute::pitch)-1))" />

<!-- If I got it correctly, pamount sets an initial positive pitch offset (up to 1 semi-tone?) from the pitch defined for the cell. pbreak allows multiples of this offset in the range from -1 to 1, but seems to be encoded in xml with a  range from 0 to 1.
We assume that both pitch eg decay times may cover the same range as time parameters of the volume envelope.
TODO: In Battery, the pitch eg may include both positive and negative deviations from the sample's root pitch. In sfz, it is only possible to let it either run into positive or negative direction (by means of pitcheg_depth), but not both. Furthermore, we model the second decay using the release in sfz which will only be applied after note off. In Battery, the pitch eg seems to be independent from note on/off. -->
		<xsl:call-template name="ifStatusBit">
			<xsl:with-param name="value">
pitcheg_depth=<xsl:value-of select="round(number(attribute::pamount)*100)" />
pitcheg_start=0
pitcheg_attack=0
pitcheg_decay=<xsl:value-of select="number(attribute::pdecay1)*$maxEGTime div 127" />
			<xsl:choose>
				<xsl:when test="number(attribute::pbreak) &gt; 0.5">
pitcheg_sustain=<xsl:value-of select="number(attribute::pbreak)*100" />
				</xsl:when>
				<xsl:otherwise>
pitcheg_sustain=0
				</xsl:otherwise>
			</xsl:choose>
pitcheg_release=<xsl:value-of select="number(attribute::pdecay2)*$maxEGTime div 127" />
			</xsl:with-param>
			<xsl:with-param name="status" select="number(attribute::status)" />
			<xsl:with-param name="index" select="8" />
		</xsl:call-template>

<!-- TODO: sample start: what is sstartUnit used for?! -->
<!-- TODO: Sample start modulation: ampeg_delay, ampeg_vel2delay. delay time = ampeg_delay + ampeg_vel2delay * velocity / 127. (ca. 20ms seems to be reasonable, cf. p.34 in Battery 3 manual -> delay: 0.02, vel2delay: -0.02) -->
offset=<xsl:value-of select="attribute::sstart" />
<!-- Loop information is given by fxstart="10" fxlength="12" fxcount="127" -->
<!-- waveShaper="4.000000" seems to be the default -->
		<xsl:apply-templates />
	</xsl:template>

	<xsl:template match="Sample">
&lt;region><xsl:text />
		<xsl:choose>
			<xsl:when test="$uppercaseFileNames = 'yes'">
sample=<xsl:value-of select="$pathPrefix" /><xsl:value-of select="translate(attribute::file, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')" />
			</xsl:when>
			<xsl:otherwise>
sample=<xsl:value-of select="$pathPrefix" /><xsl:value-of select="attribute::file" />
			</xsl:otherwise>
		</xsl:choose>
hivel=<xsl:value-of select="attribute::highVelo" />
lovel=<xsl:value-of select="attribute::lowVelo" />
<!-- TODO: use transpose and tune to fine tune a sample for a specific song -->
	</xsl:template>

	<!--
		Attribute "status" seems to be used to enable certain features like volume and pitch egs. In xml, it is given as a plain number whose bit-wise representation seems to be employed at run time. The following values are pure guesses based on the inspection of some example Battery v1 kit files:
		
		0: unknown
		1: unknown
		2: unknown
		3: (Keyboard Pitch) Track on/off
		4: AHD / AHDSR Volume EG switch
		5: Volume EG on/off
		6: Loop on/off
		7: unknown
		8: Pitch EG on/off
		9: (Cell) on/off
		10: FX Loop on/off
	-->
	<xsl:template name="ifStatusBit">
		<xsl:param name="value" />
		<xsl:param name="elseValue" />
		<xsl:param name="status" />
		<xsl:param name="index" />
		
		<xsl:choose>
			<xsl:when test="$index > 0">
				<xsl:call-template name="ifStatusBit">
					<xsl:with-param name="value" select="$value" />
					<xsl:with-param name="elseValue" select="$elseValue" />
					<xsl:with-param name="status" select="floor($status div 2)" />
					<xsl:with-param name="index" select="$index - 1" />
				</xsl:call-template>
			</xsl:when>
			<xsl:when test="$status mod 2 = 1">
				<xsl:value-of select="$value" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$elseValue" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!--
		Approximation of 10*log10() for an input range of 0-1.
	-->
	<xsl:template name="approximateLog">
		<xsl:param name="value" />

		<xsl:choose>
			<xsl:when test="$value > 0.99">
			<xsl:text>0.0</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.98">
			<xsl:text>-0.043648054024500886</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.97">
			<xsl:text>-0.0877392430750515</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.96">
			<xsl:text>-0.1322826573375516</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.95">
			<xsl:text>-0.17728766960431602</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.94">
			<xsl:text>-0.22276394711152253</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.93">
			<xsl:text>-0.2687214640030136</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.92">
			<xsl:text>-0.31517051446064853</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.91">
			<xsl:text>-0.3621217265444471</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.90">
			<xsl:text>-0.4095860767890638</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.89">
			<xsl:text>-0.4575749056067512</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.88">
			<xsl:text>-0.506099933550872</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.87">
			<xsl:text>-0.5551732784983137</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.86">
			<xsl:text>-0.6048074738138147</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.85">
			<xsl:text>-0.6550154875643228</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.84">
			<xsl:text>-0.7058107428570727</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.83">
			<xsl:text>-0.7572071393811836</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.82">
			<xsl:text>-0.8092190762392611</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.81">
			<xsl:text>-0.8618614761628333</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.80">
			<xsl:text>-0.9151498112135021</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.79">
			<xsl:text>-0.9691001300805638</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.78">
			<xsl:text>-1.0237290870955853</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.77">
			<xsl:text>-1.0790539730951958</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.76">
			<xsl:text>-1.1350927482751811</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.75">
			<xsl:text>-1.1918640771920863</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.74">
			<xsl:text>-1.2493873660829993</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.73">
			<xsl:text>-1.3076828026902378</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.72">
			<xsl:text>-1.3667713987954409</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.71">
			<xsl:text>-1.4266750356873155</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.70">
			<xsl:text>-1.4874165128092471</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.69">
			<xsl:text>-1.5490195998574319</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.68">
			<xsl:text>-1.6115090926274471</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.67">
			<xsl:text>-1.6749108729376365</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.66">
			<xsl:text>-1.7392519729917353</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.65">
			<xsl:text>-1.8045606445813132</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.64">
			<xsl:text>-1.8708664335714438</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.63">
			<xsl:text>-1.9382002601611281</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.62">
			<xsl:text>-2.0065945054641827</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.61">
			<xsl:text>-2.076083105017461</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.60">
			<xsl:text>-2.1467016498923295</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.59">
			<xsl:text>-2.218487496163563</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.58">
			<xsl:text>-2.291479883578558</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.57">
			<xsl:text>-2.3657200643706275</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.56">
			<xsl:text>-2.4412514432750863</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.55">
			<xsl:text>-2.5181197299379954</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.54">
			<xsl:text>-2.596373105057561</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.53">
			<xsl:text>-2.6760624017703143</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.52">
			<xsl:text>-2.757241303992109</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.51">
			<xsl:text>-2.8399665636520077</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.50">
			<xsl:text>-2.924298239020636</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.49">
			<xsl:text>-3.0102999566398116</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.48">
			<xsl:text>-3.0980391997148633</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.47">
			<xsl:text>-3.1875876262441274</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.46">
			<xsl:text>-3.279021420642825</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.45">
			<xsl:text>-3.3724216831842586</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.44">
			<xsl:text>-3.467874862246563</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.43">
			<xsl:text>-3.5654732351381253</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.42">
			<xsl:text>-3.6653154442041345</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.41">
			<xsl:text>-3.7675070960209953</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.40">
			<xsl:text>-3.872161432802645</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.39">
			<xsl:text>-3.979400086720375</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.38">
			<xsl:text>-4.089353929735008</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.37">
			<xsl:text>-4.202164033831898</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.36">
			<xsl:text>-4.317982759330049</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.35">
			<xsl:text>-4.436974992327126</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.34">
			<xsl:text>-4.559319556497244</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.33">
			<xsl:text>-4.685210829577447</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.32">
			<xsl:text>-4.814860601221125</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.31">
			<xsl:text>-4.94850021680094</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.30">
			<xsl:text>-5.086383061657272</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.29">
			<xsl:text>-5.228787452803376</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.28">
			<xsl:text>-5.376020021010439</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.27">
			<xsl:text>-5.528419686577807</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.26">
			<xsl:text>-5.686362358410126</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.25">
			<xsl:text>-5.850266520291819</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.24">
			<xsl:text>-6.020599913279623</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.23">
			<xsl:text>-6.197887582883939</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.22">
			<xsl:text>-6.382721639824071</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.21">
			<xsl:text>-6.575773191777937</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.20">
			<xsl:text>-6.7778070526608065</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.19">
			<xsl:text>-6.9897000433601875</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.18">
			<xsl:text>-7.21246399047171</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.17">
			<xsl:text>-7.447274948966939</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.16">
			<xsl:text>-7.695510786217259</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.15">
			<xsl:text>-7.958800173440752</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.14">
			<xsl:text>-8.239087409443187</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.13">
			<xsl:text>-8.538719643217618</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.12">
			<xsl:text>-8.86056647693163</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.11">
			<xsl:text>-9.20818753952375</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.10">
			<xsl:text>-9.586073148417748</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.9">
			<xsl:text>-9.999999999999998</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.8">
			<xsl:text>-10.457574905606752</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.7">
			<xsl:text>-10.969100130080564</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.6">
			<xsl:text>-11.54901959985743</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.5">
			<xsl:text>-12.218487496163561</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.4">
			<xsl:text>-13.010299956639809</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.3">
			<xsl:text>-13.979400086720375</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.2">
			<xsl:text>-15.228787452803376</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.1">
			<xsl:text>-16.989700043360184</xsl:text>
			</xsl:when>
			<xsl:when test="$value > 0.0">
			<xsl:text>-19.999999999999996</xsl:text>
			</xsl:when>
		</xsl:choose>
	</xsl:template>

</xsl:stylesheet>
