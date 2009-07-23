package org.jmx4perl.converter.attribute.stats;

import org.jmx4perl.converter.attribute.ObjectToJsonConverter;
import org.json.simple.JSONObject;

import javax.management.AttributeNotFoundException;
import javax.management.j2ee.statistics.*;
import java.util.Stack;

/*
 * jmx4perl - WAR Agent for exporting JMX via JSON
 *
 * Copyright (C) 2009 Roland Huß, roland@cpan.org
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * A commercial license is available as well. Please contact roland@cpan.org for
 * further details.
 */

/**
 * @author roland
 * @since Jul 10, 2009
 */
public class JmsProducerStatsHandler extends StatsHandler {

    @Override
    public Class getType() {
        return JMSProducerStats.class;
    }

    @Override
    public Object extractObject(ObjectToJsonConverter pConverter,
                                Object pValue,
                                Stack<String> pExtraArgs, boolean jsonify)
            throws AttributeNotFoundException {
        JMSProducerStats jStats = (JMSProducerStats) pValue;
        if (!pExtraArgs.isEmpty()) {
            String key = pExtraArgs.peek();
            if (key.equalsIgnoreCase("destination")) {
                return jStats.getDestination();
            } else {
                return super.extractObject(pConverter,pValue,pExtraArgs,jsonify);
            }
        } else {
            if (jsonify) {
                JSONObject ret = (JSONObject) super.extractObject(pConverter,pValue,pExtraArgs,jsonify);
                ret.put("destination",jStats.getDestination());
                return ret;
            } else {
                return jStats;
            }
        }
    }

}